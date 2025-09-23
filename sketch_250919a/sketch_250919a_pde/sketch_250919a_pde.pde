// === Movement Architecture Visualizer + Key-Pose Timeline ===
// Save as a single Processing sketch (.pde) in the same folder as your JSON
// JSON format expected:
// {
//   "metadata": {"total_frames": INT, "tracked_points": [...], "fps": (optional FLOAT)},
//   "trajectories": {
//      "0": {"points": {"left_wrist": {"x":..., "y":..., "z":...}, ...}},
//      "1": {...},
//      ...
//   }
// }

import java.util.HashMap;
import java.util.ArrayList;

// ------------ File / data ------------
String TRAJ_FILE = "cunningham_trajectories.json";

// ------------ Globals (existing) ------------
JSONObject trajectoryData;
ArrayList<ArrayList<PVector>> bodyTrajectories;
String[] trackedPoints;
int currentFrame = 0;
int totalFrames = 0;
boolean isPlaying = false;
boolean showTrails = true;
boolean showCurrentPose = false;
float playbackSpeed = 1.0;
int trailLength = 100;
float strokeWeight = 2.0;

// Animation and visual settings
float time = 0;
boolean rainbow = false;
boolean kandinskyMode = false;

// === Geometry Pack ===
int geometryMode = 0;          // 0..5
boolean showNormPoseGuide = false; // toggle helper overlay

// geometry params (tweak live if you want)
float GEOM_meshRadius = 1.0;   // in normalized units
int   GEOM_meshMaxDeg = 4;
float GEOM_starStep = 2;       // star polygon step
float GEOM_lissFreqX = 2.0, GEOM_lissFreqY = 3.0;
float GEOM_ribbonAmp = 0.35;
int   GEOM_roseN = 7;          // number of petals

// ------------ Pose-capture config ------------
float fps = 30;                 // will be overridden if JSON has metadata.fps
float stableSeconds = 1.0;      // "held" duration to consider a stable pose
int   W = int(stableSeconds * fps); // sliding window length (frames)
float velThresh = 2.0;          // px/frame mean speed threshold (tune)
float angleVarThresh = 0.02;    // rad^2 variance threshold over window (tune)
float distinctThresh = 0.15;    // cosine distance threshold to avoid duplicates (tune)
int   thumbW = 120, thumbH = 120;

// Buffers for stability test
ArrayList<float[]> sigBuffer = new ArrayList<float[]>(); // last W signatures
ArrayList<Float>   velBuffer = new ArrayList<Float>();   // last W velocities
ArrayList<PImage>  poseThumbnails = new ArrayList<PImage>();
float[] lastCapturedSig = null;
int     lastCaptureFrame = -100000;

// Useful labels (joint names expected in JSON)
String LW="left_wrist", LE="left_elbow", LS="left_shoulder";
String RW="right_wrist", RE="right_elbow", RS="right_shoulder";
String LH="left_hip", RH="right_hip", LK="left_knee", RK="right_knee";
String LA="left_ankle", RA="right_ankle", NOSE="nose";

void setup() {
  size(1200, 800);
  colorMode(RGB, 255);
  background(232, 213, 188); // #E8D5BC

  loadTrajectoryData(TRAJ_FILE);

  println("Dance Trajectory Visualizer Loaded!");
  println("Controls:");
  println("SPACE - Play/Pause");
  println("R - Reset to beginning");
  println("T - Toggle trails");
  println("P - Toggle current pose");
  println("UP/DOWN - Adjust playback speed");
  println("LEFT/RIGHT - Manual frame control");
  println("1-9 - Set trail length");
  println("S - Save frame");
  println("C - Clear screen");
  println("B - Toggle rainbow mode");
  println("K - Toggle Kandinsky mode");
}

void draw() {
  // Creamy fade
  fill(232, 213, 188, 20);
  noStroke();
  rect(0, 0, width, height);

  if (trajectoryData != null) {
    // Playback
    if (isPlaying && currentFrame < totalFrames - 1) {
      currentFrame += int(playbackSpeed);
      if (currentFrame >= totalFrames) currentFrame = totalFrames - 1;
    }

    // --- Pose stability pipeline ---
    if (currentFrame > 1 && currentFrame < totalFrames) {
      float[] sig = computePoseSignature(currentFrame);
      float v = meanLandmarkVelocity(currentFrame - 1, currentFrame);

      if (sig != null) {
        sigBuffer.add(sig);
        velBuffer.add(v);
        if (sigBuffer.size() > W) sigBuffer.remove(0);
        if (velBuffer.size() > W) velBuffer.remove(0);

        if (sigBuffer.size() == W && velBuffer.size() == W) {
          if (isStable(sigBuffer, velBuffer)) {
            if (isDistinct(sig, lastCapturedSig)) {
              capturePoseThumbnail(currentFrame);
              lastCapturedSig = sig;
              lastCaptureFrame = currentFrame;
            }
          }
        }
      }
    }

    // Draw trajectories
    if (showTrails) drawTrajectoryTrails();

    // (Optional) pose drawing is currently disabled to keep canvas clean
    if (showCurrentPose) drawCurrentPose();

    // UI overlay
    drawUI();
    
    drawGeometryOverPose();

    // Timeline of key poses along left → right
    drawPoseTimeline();
  }

  time += 0.02;
}

// ---------------- Data loading ----------------
void loadTrajectoryData(String filename) {
  try {
    trajectoryData = loadJSONObject(filename);
    if (trajectoryData != null) {
      JSONObject metadata = trajectoryData.getJSONObject("metadata");
      totalFrames = metadata.getInt("total_frames");

      // fps (optional)
      if (metadata.hasKey("fps")) {
        fps = metadata.getFloat("fps");
      }
      W = int(stableSeconds * fps);

      // Tracked points list
      JSONArray pointsArray = metadata.getJSONArray("tracked_points");
      trackedPoints = new String[pointsArray.size()];
      for (int i = 0; i < pointsArray.size(); i++) {
        trackedPoints[i] = pointsArray.getString(i);
      }

      // Trajectories
      bodyTrajectories = new ArrayList<ArrayList<PVector>>();
      JSONObject trajectories = trajectoryData.getJSONObject("trajectories");

      for (int i = 0; i < trackedPoints.length; i++) {
        bodyTrajectories.add(new ArrayList<PVector>());
      }

      for (int frame = 0; frame < totalFrames; frame++) {
        if (trajectories.hasKey(str(frame))) {
          JSONObject frameData = trajectories.getJSONObject(str(frame));
          JSONObject points = frameData.getJSONObject("points");

          for (int i = 0; i < trackedPoints.length; i++) {
            String pointName = trackedPoints[i];
            if (points.hasKey(pointName)) {
              JSONObject p = points.getJSONObject(pointName);
              float x = p.getFloat("x");
              float y = p.getFloat("y");
              float z = p.getFloat("z");
              bodyTrajectories.get(i).add(new PVector(x, y, z));
            } else {
              bodyTrajectories.get(i).add(null);
            }
          }
        } else {
          // no entry for this frame: pad nulls
          for (int i = 0; i < trackedPoints.length; i++) {
            bodyTrajectories.get(i).add(null);
          }
        }
      }

      println("Loaded " + totalFrames + " frames, fps=" + fps + ", W=" + W);
    }
  } catch (Exception e) {
    println("Could not load trajectory data. Make sure '" + filename + "' is in the sketch folder.");
    println("Error: " + e.getMessage());
  }
}

// ---------------- Drawing ----------------
void drawTrajectoryTrails() {
  for (int i = 0; i < trackedPoints.length; i++) {
    String pointName = trackedPoints[i];
    ArrayList<PVector> trajectory = bodyTrajectories.get(i);

    if (trajectory.size() > 1) {
      // Choose color
      int pointColor;
      if (rainbow) {
        colorMode(HSB, 360, 100, 100);
        pointColor = color((frameCount + pointName.hashCode()) % 360, 80, 90);
        colorMode(RGB, 255);
      } else {
        pointColor = color(0); // black
      }

      int startFrame = max(0, currentFrame - trailLength);
      int endFrame   = min(currentFrame, trajectory.size() - 1);

      if (kandinskyMode) {
        drawKandinskyStyle(trajectory, startFrame, endFrame, pointColor);
      } else {
        drawRegularTrail(trajectory, startFrame, endFrame, pointColor);
      }
    }
  }
}

void drawRegularTrail(ArrayList<PVector> trajectory, int startFrame, int endFrame, int pointColor) {
  for (int j = startFrame; j < endFrame; j++) {
    PVector a = trajectory.get(j);
    PVector b = trajectory.get(j + 1);
    if (a != null && b != null) {
      float dist = PVector.dist(a, b);
      float weight = map(dist, 0, 50, 0.5, strokeWeight * 3);
      weight = constrain(weight, 0.5, 6);

      stroke(pointColor);
      strokeWeight(weight);
      line(a.x, a.y, b.x, b.y);
      // (particles removed for clean lines)
    }
  }
}

void drawKandinskyStyle(ArrayList<PVector> trajectory, int startFrame, int endFrame, int pointColor) {
  for (int j = startFrame; j < endFrame - 2; j++) {
    PVector p1 = trajectory.get(j);
    PVector p2 = trajectory.get(j + 1);
    PVector p3 = trajectory.get(j + 2);
    if (p1 != null && p2 != null && p3 != null) {
      float distance = PVector.dist(p1, p2);
      float weight = map(distance, 0, 50, 1, 8);
      weight = constrain(weight, 1, 12);
      float tension = map(sin(j * 0.1 + time), -1, 1, 0.1, 0.9);

      stroke(pointColor);
      strokeWeight(weight);
      noFill();
      bezier(p1.x, p1.y,
             lerp(p1.x, p2.x, tension), lerp(p1.y, p2.y, tension),
             lerp(p2.x, p3.x, 1 - tension), lerp(p2.y, p3.y, 1 - tension),
             p3.x, p3.y);

      if (distance > 25) {
        drawKandinskyElements(p2, distance, pointColor);
      }
      if (distance < 10 && random(1) < 0.3) {
        drawDottedLine(p1, p2, pointColor);
      }
    }
  }
}

void drawKandinskyElements(PVector pos, float intensity, int lineColor) {
  pushMatrix();
  translate(pos.x, pos.y);
  float size = map(intensity, 20, 50, 5, 25);
  int elementType = int(random(4));
  stroke(lineColor);
  strokeWeight(2);
  noFill();

  switch (elementType) {
    case 0: ellipse(0, 0, size, size); break; // circle
    case 1: triangle(-size/2, size/3, size/2, size/3, 0, -size/2); break; // triangle
    case 2:
      for (int i = 0; i < 6; i++) {
        float ang = i * PI / 3;
        float len = size/3;
        line(0, 0, cos(ang) * len, sin(ang) * len);
      }
      break;
    case 3: arc(0, 0, size, size, 0, PI); break; // arc
  }
  popMatrix();
}

void drawDottedLine(PVector a, PVector b, int c) {
  stroke(c);
  strokeWeight(3);
  float d = PVector.dist(a, b);
  int dots = int(d / 5);
  for (int i = 0; i <= dots; i++) {
    float t = i / float(dots);
    point(lerp(a.x, b.x, t), lerp(a.y, b.y, t));
  }
}

// (kept for compatibility with your toggles, but empty for now)
void drawCurrentPose() {
  Pose2D p = normalizedPose(currentFrame);
  if (p == null) return;

  pushMatrix();
  translate(width * 0.75, height * 0.5); // position on screen (adjust as needed)
  scale(150); // scale normalized coords to screen size
  drawSkeletonIntoGraphics(g, p); // reuse existing skeleton drawing
  popMatrix();
}

// Pose connections helpers (optional, not used currently)
void drawPoseConnections() {
  String[][] connections = {
    {"left_shoulder", "right_shoulder"},
    {"left_shoulder", "left_elbow"},
    {"right_shoulder", "right_elbow"},
    {"left_elbow", "left_wrist"},
    {"right_elbow", "right_wrist"},
    {"left_shoulder", "left_hip"},
    {"right_shoulder", "right_hip"},
    {"left_hip", "right_hip"},
    {"left_hip", "left_knee"},
    {"right_hip", "right_knee"},
    {"left_knee", "left_ankle"},
    {"right_knee", "right_ankle"}
  };
  for (String[] c : connections) drawConnection(c[0], c[1]);
}

void drawConnection(String p1n, String p2n) {
  int i1 = findPointIndex(p1n);
  int i2 = findPointIndex(p2n);
  if (i1 >= 0 && i2 >= 0) {
    ArrayList<PVector> t1 = bodyTrajectories.get(i1);
    ArrayList<PVector> t2 = bodyTrajectories.get(i2);
    if (currentFrame < t1.size() && currentFrame < t2.size()) {
      PVector p1 = t1.get(currentFrame);
      PVector p2 = t2.get(currentFrame);
      if (p1 != null && p2 != null) {
        stroke(0);
        line(p1.x, p1.y, p2.x, p2.y);
      }
    }
  }
}

int findPointIndex(String pointName) {
  if (trackedPoints == null) return -1;
  for (int i = 0; i < trackedPoints.length; i++) {
    if (trackedPoints[i].equals(pointName)) return i;
  }
  return -1;
}

// ---------------- UI ----------------
void drawUI() {
  fill(0, 150);
  noStroke();
  rect(10, height - 120, 300, 110);

  fill(255);
  textSize(12);
  text("Frame: " + currentFrame + "/" + max(0, totalFrames - 1), 20, height - 100);
  text("Speed: " + nf(playbackSpeed, 1, 1) + "x", 20, height - 85);
  text("Trail Length: " + trailLength, 20, height - 70);
  text("Playing: " + (isPlaying ? "YES" : "NO"), 20, height - 55);
  text("Trails: " + (showTrails ? "ON" : "OFF"), 20, height - 40);
  text("Pose: " + (showCurrentPose ? "ON" : "OFF"), 20, height - 25);

  // Progress bar
  stroke(255);
  strokeWeight(2);
  line(20, height - 10, 280, height - 10);
  if (totalFrames > 0) {
    float progress = map(currentFrame, 0, totalFrames - 1, 20, 280);
    fill(200, 80, 90);
    noStroke();
    ellipse(progress, height - 10, 8, 8);
  }
}

void drawPoseTimeline() {
  // Draw thumbnails along the left margin, left→right, wrapping
  int marginX = 20, marginY = 20, gap = 10;
  int x = marginX, y = marginY;

  // reserve vertical space (avoid overlapping UI)
  int maxY = height - 140;

  for (int i = 0; i < poseThumbnails.size(); i++) {
    image(poseThumbnails.get(i), x, y, thumbW, thumbH);
    x += thumbW + gap;
    if (x + thumbW + gap > width) { x = marginX; y += thumbH + gap; }
    if (y + thumbH > maxY) break; // stop drawing if we’d overlap UI
  }
}

// ---------------- Input ----------------
void keyPressed() {
  switch (key) {
    case ' ': isPlaying = !isPlaying; break;
    case 'r': case 'R': currentFrame = 0; break;
    case 't': case 'T': showTrails = !showTrails; break;
    case 'p': case 'P': showCurrentPose = !showCurrentPose; break;
    case 's': case 'S': saveFrame("dance-frame-####.png"); println("Frame saved!"); break;
    case 'c': case 'C': background(232, 213, 188); break;
    case 'b': case 'B': rainbow = !rainbow; break;
    case 'k': case 'K': kandinskyMode = !kandinskyMode; println("Kandinsky mode: " + (kandinskyMode ? "ON" : "OFF")); break;
    case 'g': case 'G':
      geometryMode = (geometryMode + 1) % 6;
      println("Geometry mode: " + geometryMode);
      break;
    case '`': // backtick to see normalized pose anchor
      showNormPoseGuide = !showNormPoseGuide;
      break;

  }

  if (key >= '1' && key <= '9') trailLength = (key - '0') * 20;

  if (keyCode == UP)       { playbackSpeed = min(playbackSpeed + 0.2, 3.0); }
  else if (keyCode == DOWN){ playbackSpeed = max(playbackSpeed - 0.2, 0.2); }
  else if (keyCode == LEFT && currentFrame > 0) {
    currentFrame--; isPlaying = false;
  } else if (keyCode == RIGHT && currentFrame < totalFrames - 1) {
    currentFrame++; isPlaying = false;
  }
}

void mousePressed() {
  if (mouseY > height - 20 && mouseY < height && mouseX > 20 && mouseX < 280) {
    float newFrame = map(mouseX, 20, 280, 0, totalFrames - 1);
    currentFrame = constrain(int(newFrame), 0, totalFrames - 1);
    isPlaying = false;
  }
}
void mouseDragged() { mousePressed(); }

// ---------------- Pose math ----------------
int idx(String name) { return findPointIndex(name); }

PVector getPt(int frame, String name) {
  int i = idx(name);
  if (i < 0) return null;
  ArrayList<PVector> traj = bodyTrajectories.get(i);
  if (frame < 0 || frame >= traj.size()) return null;
  return traj.get(frame);
}

class Pose2D {
  HashMap<String, PVector> pts = new HashMap<String, PVector>();
}

Pose2D normalizedPose(int frame) {
  Pose2D p = new Pose2D();
  PVector lhip = getPt(frame, LH);
  PVector rhip = getPt(frame, RH);
  PVector lsh  = getPt(frame, LS);
  PVector rsh  = getPt(frame, RS);
  if (lhip == null || rhip == null || lsh == null || rsh == null) return null;

  PVector center = PVector.add(lhip, rhip).mult(0.5);
  float scale = max(1e-3, PVector.dist(PVector.add(lsh, rsh).mult(0.5), center)); // torso length

  for (String name : trackedPoints) {
    PVector q = getPt(frame, name);
    if (q != null) {
      PVector n = new PVector((q.x - center.x)/scale, (q.y - center.y)/scale);
      p.pts.put(name, n);
    }
  }
  return p;
}

float angleAt(PVector a, PVector b, PVector c) {
  if (a == null || b == null || c == null) return Float.NaN;
  PVector u = PVector.sub(a, b);
  PVector v = PVector.sub(c, b);
  float nu = u.mag(), nv = v.mag();
  if (nu < 1e-6 || nv < 1e-6) return Float.NaN;
  float cosv = constrain(PVector.dot(u, v) / (nu * nv), -1, 1);
  return acos(cosv);
}

// Signature = 8 joint angles + 5 normalized Y coords (wrist/ankle/nose) to capture silhouette
float[] computePoseSignature(int frame) {
  Pose2D p = normalizedPose(frame);
  if (p == null) return null;

  float aLE = angleAt(p.pts.get(LS), p.pts.get(LE), p.pts.get(LW));
  float aRE = angleAt(p.pts.get(RS), p.pts.get(RE), p.pts.get(RW));
  float aLK = angleAt(p.pts.get(LH), p.pts.get(LK), p.pts.get(LA));
  float aRK = angleAt(p.pts.get(RH), p.pts.get(RK), p.pts.get(RA));
  float aLS = angleAt(p.pts.get(LE), p.pts.get(LS), p.pts.get(LH));
  float aRS = angleAt(p.pts.get(RE), p.pts.get(RS), p.pts.get(RH));
  float aLH = angleAt(p.pts.get(LS), p.pts.get(LH), p.pts.get(LK));
  float aRH = angleAt(p.pts.get(RS), p.pts.get(RH), p.pts.get(RK));

  float[] angles = {aLE,aRE,aLK,aRK,aLS,aRS,aLH,aRH};
  for (int i = 0; i < angles.length; i++) if (Float.isNaN(angles[i])) angles[i] = 0;

  float[] extras = new float[]{
    getY(p, LW), getY(p, RW), getY(p, LA), getY(p, RA), getY(p, NOSE)
  };

  float[] sig = new float[angles.length + extras.length];
  arrayCopy(angles, 0, sig, 0, angles.length);
  arrayCopy(extras, 0, sig, angles.length, extras.length);
  return sig;
}

float getY(Pose2D p, String name) {
  PVector q = p.pts.get(name);
  return (q == null) ? 0 : q.y;
}

// Mean per-frame landmark speed (screen space)
float meanLandmarkVelocity(int f0, int f1) {
  float sum = 0; int count = 0;
  for (String name : trackedPoints) {
    PVector a = getPt(f0, name), b = getPt(f1, name);
    if (a != null && b != null) { sum += PVector.dist(a, b); count++; }
  }
  return (count > 0) ? sum / count : 0;
}

// Stability: (1) low velocity over window, (2) low angle variance over window
boolean isStable(ArrayList<float[]> sigs, ArrayList<Float> vels) {
  float mv = 0;
  for (float v : vels) mv += v;
  mv /= max(1, vels.size());
  if (mv > velThresh) return false;

  int A = 8; // first 8 dims are angles
  int n = sigs.size();
  float[] mean = new float[A];
  for (float[] s : sigs) for (int i = 0; i < A; i++) mean[i] += s[i];
  for (int i = 0; i < A; i++) mean[i] /= n;

  float varSum = 0;
  for (float[] s : sigs) for (int i = 0; i < A; i++) {
    float d = s[i] - mean[i];
    varSum += d * d;
  }
  float angleVar = varSum / (A * n);
  return angleVar < angleVarThresh;
}

// Distinctness: cosine distance against last captured signature
boolean isDistinct(float[] a, float[] b) {
  if (a == null || b == null) return true;
  float dot = 0, na = 0, nb = 0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na  += a[i] * a[i];
    nb  += b[i] * b[i];
  }
  if (na < 1e-9 || nb < 1e-9) return true;
  float cos = dot / (sqrt(na) * sqrt(nb));
  float dist = 1 - cos;
  return dist > distinctThresh;
}

// Capture a small thumbnail of the normalized skeleton at current frame
void capturePoseThumbnail(int frame) {
  PGraphics g = createGraphics(thumbW, thumbH);
  g.beginDraw();
  g.background(232, 213, 188);
  g.stroke(0); g.fill(0);
  Pose2D p = normalizedPose(frame);
  if (p != null) {
    g.pushMatrix();
    g.translate(thumbW * 0.5, thumbH * 0.6);
    g.scale(thumbH * 0.25); // scale normalized coords into thumbnail space
    drawSkeletonIntoGraphics(g, p);
    g.popMatrix();
  }
  g.endDraw();
  poseThumbnails.add(g.get());
  println("Captured pose thumbnail at frame " + frame + " (#" + poseThumbnails.size() + ")");
}

void drawSkeletonIntoGraphics(PGraphics g, Pose2D p) {
  String[][] bones = {
    {LS, RS}, {LS, LE}, {LE, LW}, {RS, RE}, {RE, RW},
    {LS, LH}, {RS, RH}, {LH, RH}, {LH, LK}, {LK, LA}, {RH, RK}, {RK, RA}
  };
  g.stroke(30); g.strokeWeight(0.06);
  for (String[] b : bones) {
    PVector a = p.pts.get(b[0]);
    PVector c = p.pts.get(b[1]);
    if (a != null && c != null) g.line(a.x, a.y, c.x, c.y);
  }
  g.noStroke(); g.fill(10);
  for (PVector q : p.pts.values()) g.circle(q.x, q.y, 0.12);
}

void drawSkeleton(Pose2D p) {
  String[][] bones = {
    {LS, RS}, {LS, LE}, {LE, LW}, {RS, RE}, {RE, RW},
    {LS, LH}, {RS, RH}, {LH, RH}, {LH, LK}, {LK, LA}, {RH, RK}, {RK, RA}
  };
  stroke(0); strokeWeight(2);
  for (String[] b : bones) {
    PVector a = p.pts.get(b[0]);
    PVector c = p.pts.get(b[1]);
    if (a != null && c != null) line(a.x, a.y, c.x, c.y);
  }
  noStroke(); fill(0);
  for (PVector q : p.pts.values()) ellipse(q.x, q.y, 6, 6);
}

// ---- geometry main ----
void drawGeometryOverPose() {
  Pose2D p = normalizedPose(currentFrame);
  if (p == null) return;

  // place normalized pose in a consistent spot (same as thumbnails but bigger)
  pushMatrix();
  translate(width * 0.72, height * 0.5);
  float S = height * 0.25; // overall scale of geometry
  scale(S);

  if (showNormPoseGuide) {
    // draw tiny guide skeleton
    stroke(0, 40); strokeWeight(0.02);
    noFill();
    drawSkeletonNormalizedLines(p);
  }

  switch (geometryMode) {
    case 0: break;
    case 1: geomPoseMesh(p);        break;
    case 2: geomConvexHullStar(p);  break;
    case 3: geomLissajousLinks(p);  break;
    case 4: geomBoneRibbons(p);     break;
    case 5: geomRoseAtCenter(p);    break;
  }

  popMatrix();
}

// ---- utility: list of normalized points available ----
ArrayList<PVector> normPointsFrom(Pose2D p) {
  ArrayList<PVector> pts = new ArrayList<PVector>();
  for (String name : trackedPoints) {
    PVector q = p.pts.get(name);
    if (q != null) pts.add(q.copy());
  }
  return pts;
}

// ---- (G1) pose mesh: connect nearby joints with limited degree ----
void geomPoseMesh(Pose2D p) {
  ArrayList<PVector> pts = normPointsFrom(p);
  // animated jitter in threshold
  float r = GEOM_meshRadius * (0.9 + 0.2 * sin(time * 0.8));
  // track degree per node
  int n = pts.size();
  int[] deg = new int[n];

  stroke(0, 140);
  for (int i = 0; i < n; i++) {
    for (int j = i+1; j < n; j++) {
      float d = PVector.dist(pts.get(i), pts.get(j));
      if (d < r && deg[i] < GEOM_meshMaxDeg && deg[j] < GEOM_meshMaxDeg) {
        float w = map(d, 0, r, 0.08, 0.01);
        strokeWeight(w);
        line(pts.get(i).x, pts.get(i).y, pts.get(j).x, pts.get(j).y);
        deg[i]++; deg[j]++;
      }
    }
  }
  // nodes
  noStroke(); fill(0);
  for (PVector q : pts) circle(q.x, q.y, 0.05);
}

// ---- (G2) convex hull + star chords ----
void geomConvexHullStar(Pose2D p) {
  ArrayList<PVector> pts = normPointsFrom(p);
  ArrayList<PVector> hull = convexHull(pts);
  if (hull.size() < 3) return;

  // hull
  noFill(); stroke(0); strokeWeight(0.025);
  beginShape();
  for (PVector q : hull) vertex(q.x, q.y);
  endShape(CLOSE);

  // animated star chords along hull indices
  int m = hull.size();
  float step = max(1, round(GEOM_starStep + 1.5 * sin(time * 0.6)));
  stroke(0, 120); strokeWeight(0.02);
  for (int i = 0; i < m; i++) {
    int j = (i + int(step)) % m;
    line(hull.get(i).x, hull.get(i).y, hull.get(j).x, hull.get(j).y);
  }
}

// Graham-scan convex hull in 2D
ArrayList<PVector> convexHull(ArrayList<PVector> pts) {
  ArrayList<PVector> p = new ArrayList<PVector>();
  for (PVector v : pts) p.add(v.copy());
  if (p.size() <= 1) return p;

  // sort by x, then y
  p.sort((a,b) -> (a.x == b.x) ? Float.compare(a.y, b.y) : Float.compare(a.x, b.x));

  ArrayList<PVector> lower = new ArrayList<PVector>();
  for (PVector v : p) {
    while (lower.size() >= 2 && cross(lower.get(lower.size()-2), lower.get(lower.size()-1), v) <= 0) {
      lower.remove(lower.size()-1);
    }
    lower.add(v);
  }
  ArrayList<PVector> upper = new ArrayList<PVector>();
  for (int i = p.size()-1; i >= 0; i--) {
    PVector v = p.get(i);
    while (upper.size() >= 2 && cross(upper.get(upper.size()-2), upper.get(upper.size()-1), v) <= 0) {
      upper.remove(upper.size()-1);
    }
    upper.add(v);
  }
  lower.remove(lower.size()-1);
  upper.remove(upper.size()-1);
  lower.addAll(upper);
  return lower;
}
float cross(PVector o, PVector a, PVector b) {
  return (a.x - o.x)*(b.y - o.y) - (a.y - o.y)*(b.x - o.x);
}

// ---- (G3) lissajous links between symmetric pairs ----
void geomLissajousLinks(Pose2D p) {
  String[][] pairs = {
    {LW, RW}, {LE, RE}, {LS, RS},
    {LA, RA}, {LK, RK}, {LH, RH}
  };
  noFill();
  for (String[] pr : pairs) {
    PVector A = p.pts.get(pr[0]), B = p.pts.get(pr[1]);
    if (A == null || B == null) continue;

    // parametric midframe lissajous sweeping between A and B
    int segs = 160;
    float amp = PVector.dist(A, B) * 0.5;
    stroke(0, 120);
    strokeWeight(0.02);
    beginShape();
    for (int i = 0; i <= segs; i++) {
      float t = i / float(segs);
      // base line between A and B
      float x0 = lerp(A.x, B.x, t);
      float y0 = lerp(A.y, B.y, t);
      // lissajous offset in a frame rotated 90 deg to the AB vector
      PVector AB = PVector.sub(B, A);
      PVector N = new PVector(-AB.y, AB.x);
      N.normalize();
      float ox = amp * 0.25 * sin(TWO_PI * (GEOM_lissFreqX * t + 0.15 * time));
      float oy = amp * 0.25 * cos(TWO_PI * (GEOM_lissFreqY * t - 0.11 * time));
      // combine offsets along normal & tangent
      PVector T = AB.copy(); T.normalize();
      float x = x0 + N.x * ox + T.x * oy * 0.6;
      float y = y0 + N.y * ox + T.y * oy * 0.6;
      vertex(x, y);
    }
    endShape();
  }
}

// ---- (G4) bone ribbons: bezier strips with thickness from motion ----
void geomBoneRibbons(Pose2D p) {
  String[][] bones = {
    {LS, RS}, {LS, LE}, {LE, LW}, {RS, RE}, {RE, RW},
    {LS, LH}, {RS, RH}, {LH, RH}, {LH, LK}, {LK, LA}, {RH, RK}, {RK, RA}
  };

  // estimate current motion energy from last two frames (reuse your velocity)
  float energy = constrain(meanLandmarkVelocity(max(0,currentFrame-2), currentFrame) / 12.0, 0, 1);

  for (String[] b : bones) {
    PVector a = p.pts.get(b[0]);
    PVector c = p.pts.get(b[1]);
    if (a == null || c == null) continue;

    // curve control based on a small oscillation + bone direction
    PVector mid = PVector.add(a, c).mult(0.5);
    PVector dir = PVector.sub(c, a);
    PVector nrm = new PVector(-dir.y, dir.x);
    if (nrm.mag() > 1e-6) nrm.normalize();
    float amp = GEOM_ribbonAmp * (0.5 + 0.5 * sin(time + a.hashCode()*0.0001));
    PVector ctrl1 = PVector.add(a, PVector.mult(nrm, amp));
    PVector ctrl2 = PVector.add(c, PVector.mult(nrm, -amp));

    // thickness from energy and bone length
    float thick = 0.02 + 0.10 * energy + 0.05 * constrain(dir.mag(), 0, 2);
    // draw as many parallel strokes to fake a ribbon
    int bands = 5;
    for (int k = 0; k < bands; k++) {
      float t = map(k, 0, bands-1, -1, 1);
      PVector offset = PVector.mult(nrm, t * thick);
      stroke(0, 50 + 40*k/bands);
      strokeWeight(0.02);
      noFill();
      bezier(a.x+offset.x, a.y+offset.y,
             ctrl1.x+offset.x, ctrl1.y+offset.y,
             ctrl2.x+offset.x, ctrl2.y+offset.y,
             c.x+offset.x, c.y+offset.y);
    }
  }
}

// ---- (G5) polar rose centered at hip-midpoint ----
void geomRoseAtCenter(Pose2D p) {
  PVector lh = p.pts.get(LH), rh = p.pts.get(RH);
  if (lh == null || rh == null) return;
  PVector center = PVector.add(lh, rh).mult(0.5);

  // scale from motion energy
  float energy = constrain(meanLandmarkVelocity(max(0,currentFrame-2), currentFrame) / 10.0, 0, 1);
  float a = 0.9 * (0.3 + 0.7*energy);  // radius
  int K = GEOM_roseN;                  // petals

  pushMatrix();
  translate(center.x, center.y);
  rotate(0.4 * time);
  noFill();
  stroke(0, 120);
  strokeWeight(0.02);
  beginShape();
  int steps = 360;
  for (int i = 0; i <= steps; i++) {
    float th = i * TWO_PI / steps;
    float r = a * cos(K * th);
    vertex(r * cos(th), r * sin(th));
  }
  endShape();
  popMatrix();
}

// ---- tiny helper to draw the guide skeleton (normalized) ----
void drawSkeletonNormalizedLines(Pose2D p) {
  String[][] bones = {
    {LS, RS}, {LS, LE}, {LE, LW}, {RS, RE}, {RE, RW},
    {LS, LH}, {RS, RH}, {LH, RH}, {LH, LK}, {LK, LA}, {RH, RK}, {RK, RA}
  };
  for (String[] b : bones) {
    PVector a = p.pts.get(b[0]);
    PVector c = p.pts.get(b[1]);
    if (a != null && c != null) line(a.x, a.y, c.x, c.y);
  }
}
