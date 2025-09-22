//// Global variables
//JSONObject trajectoryData;
//ArrayList<ArrayList<PVector>> bodyTrajectories;
//String[] trackedPoints;
//int currentFrame = 0;
//int totalFrames = 0;
//boolean isPlaying = false;
//boolean showTrails = true;
//boolean showCurrentPose = false;
//float playbackSpeed = 1.0;
//int trailLength = 100;
//float strokeWeight = 2.0;

//// Animation and visual settings
//int fadeFrames = 60;
//float time = 0;
//boolean rainbow = false;

//void setup() {
//  size(1200, 800);
//  colorMode(RGB, 255);
//  background(232, 213, 188); // #E8D5BC
  
//  // Load trajectory data
//  loadTrajectoryData("cunningham_trajectories.json");
  
//  println("Dance Trajectory Visualizer Loaded!");
//  println("Controls:");
//  println("SPACE - Play/Pause");
//  println("R - Reset to beginning");
//  println("T - Toggle trails");
//  println("P - Toggle current pose");
//  println("UP/DOWN - Adjust playback speed");
//  println("LEFT/RIGHT - Manual frame control");
//  println("1-9 - Set trail length");
//  println("S - Save frame");
//  println("C - Clear screen");
//  println("B - Toggle rainbow mode");
//}

//void draw() {
//  // Create fade effect
//  fill(232, 213, 188, 20);
//  rect(0, 0, width, height);
  
//  if (trajectoryData != null) {
//    // Update animation
//    if (isPlaying && currentFrame < totalFrames - 1) {
//      currentFrame += int(playbackSpeed);
//      if (currentFrame >= totalFrames) currentFrame = totalFrames - 1;
//    }
    
//    // Draw trajectories
//    if (showTrails) {
//      drawTrajectoryTrails();
//    }
    
//    // Draw current pose
//    if (showCurrentPose) {
//      drawCurrentPose();
//    }
    
//    // Draw UI
//    drawUI();
//  }
  
//  time += 0.02;
//}

//void loadTrajectoryData(String filename) {
//  try {
//    trajectoryData = loadJSONObject(filename);
    
//    if (trajectoryData != null) {
//      // Get metadata
//      JSONObject metadata = trajectoryData.getJSONObject("metadata");
//      totalFrames = metadata.getInt("total_frames");
      
//      // Get tracked points
//      JSONArray pointsArray = metadata.getJSONArray("tracked_points");
//      trackedPoints = new String[pointsArray.size()];
//      for (int i = 0; i < pointsArray.size(); i++) {
//        trackedPoints[i] = pointsArray.getString(i);
//      }
      
//      // Parse trajectory data
//      bodyTrajectories = new ArrayList<ArrayList<PVector>>();
//      JSONObject trajectories = trajectoryData.getJSONObject("trajectories");
      
//      // Initialize trajectory lists
//      for (int i = 0; i < trackedPoints.length; i++) {
//        bodyTrajectories.add(new ArrayList<PVector>());
//      }
      
//      // Parse each frame
//      for (int frame = 0; frame < totalFrames; frame++) {
//        if (trajectories.hasKey(str(frame))) {
//          JSONObject frameData = trajectories.getJSONObject(str(frame));
//          JSONObject points = frameData.getJSONObject("points");
          
//          for (int i = 0; i < trackedPoints.length; i++) {
//            String pointName = trackedPoints[i];
//            if (points.hasKey(pointName)) {
//              JSONObject point = points.getJSONObject(pointName);
//              float x = point.getFloat("x");
//              float y = point.getFloat("y");
//              float z = point.getFloat("z");
              
//              bodyTrajectories.get(i).add(new PVector(x, y, z));
//            } else {
//              // Add null point for missing data
//              bodyTrajectories.get(i).add(null);
//            }
//          }
//        }
//      }
      
//      println("Loaded " + totalFrames + " frames of trajectory data");
//    }
//  } catch (Exception e) {
//    println("Could not load trajectory data. Make sure 'dance_trajectories.json' is in the sketch folder.");
//    println("Error: " + e.getMessage());
//  }
//}

//color getBodyPartColor(String pointName) {
//  // Return colors for different body parts
//  if (pointName.equals("left_wrist")) return color(0, 80, 90);      // Red
//  if (pointName.equals("right_wrist")) return color(20, 80, 90);    // Orange
//  if (pointName.equals("left_elbow")) return color(60, 80, 80);     // Yellow
//  if (pointName.equals("right_elbow")) return color(80, 80, 80);    // Light Green
//  if (pointName.equals("left_shoulder")) return color(120, 80, 90); // Green
//  if (pointName.equals("right_shoulder")) return color(160, 80, 90); // Teal
//  if (pointName.equals("left_hip")) return color(200, 80, 80);      // Blue
//  if (pointName.equals("right_hip")) return color(220, 80, 80);     // Deep Blue
//  if (pointName.equals("left_knee")) return color(260, 80, 70);     // Purple
//  if (pointName.equals("right_knee")) return color(280, 80, 70);    // Magenta
//  if (pointName.equals("left_ankle")) return color(300, 80, 80);    // Pink
//  if (pointName.equals("right_ankle")) return color(320, 80, 80);   // Rose
//  if (pointName.equals("nose")) return color(40, 80, 95);           // Bright Yellow
//  if (pointName.equals("left_heel")) return color(340, 80, 75);     // Deep Pink
//  if (pointName.equals("right_heel")) return color(350, 80, 75);    // Red Pink
  
//  // Default color
//  return color(180, 60, 80);
//}

//void drawTrajectoryTrails() {
//  for (int i = 0; i < trackedPoints.length; i++) {
//    String pointName = trackedPoints[i];
//    ArrayList<PVector> trajectory = bodyTrajectories.get(i);
    
//    if (trajectory.size() > 1) {
//      // Get color for this body part
//      color pointColor;
//      if (rainbow) {
//        colorMode(HSB, 360, 100, 100);
//        pointColor = color((frameCount + pointName.hashCode()) % 360, 80, 90);
//        colorMode(RGB, 255);
//      } else {
//        pointColor = color(0); // Black lines when rainbow is off
//      }
      
//      // Draw trail
//      int startFrame = max(0, currentFrame - trailLength);
//      int endFrame = min(currentFrame, trajectory.size() - 1);
      
//      for (int j = startFrame; j < endFrame; j++) {
//        PVector current = trajectory.get(j);
//        PVector next = trajectory.get(j + 1);
        
//        if (current != null && next != null) {
//          // Calculate alpha based on how recent the point is
//          float alpha = map(j, startFrame, endFrame, 10, 100);
          
//          // Calculate stroke weight based on velocity
//          float distance = PVector.dist(current, next);
//          float weight = map(distance, 0, 50, 0.5, strokeWeight * 3);
//          weight = constrain(weight, 0.5, 6);
          
//          // Set style
//          stroke(pointColor);
//          strokeWeight(weight);
          
//          // Draw line segment
//          line(current.x, current.y, next.x, next.y);
          
//          // Add particle effects for fast movements
//          if (distance > 20) {
//            drawMotionParticle(current, next, pointColor, alpha);
//          }
//        }
//      }
//    }
//  }
//}

//void drawMotionParticle(PVector start, PVector end, color c, float alpha) {
//  pushMatrix();
//  translate(lerp(start.x, end.x, 0.5), lerp(start.y, end.y, 0.5));
  
//  fill(c);
//  noStroke();
  
//  float size = random(2, 6);
//  ellipse(random(-3, 3), random(-3, 3), size, size);
  
//  popMatrix();
//}

//void drawCurrentPose() {
//  if (currentFrame < totalFrames && bodyTrajectories.size() > 0) {
//    // Draw connections between body parts
//    stroke(0, 0, 100, 60);
//    strokeWeight(1);
//    drawPoseConnections();
    
//    // Draw current points
//    for (int i = 0; i < trackedPoints.length; i++) {
//      String pointName = trackedPoints[i];
//      ArrayList<PVector> trajectory = bodyTrajectories.get(i);
      
//      if (currentFrame < trajectory.size()) {
//        PVector point = trajectory.get(currentFrame);
        
//        if (point != null) {
//          color pointColor;
//          if (rainbow) {
//            colorMode(HSB, 360, 100, 100);
//            pointColor = color((frameCount + pointName.hashCode()) % 360, 80, 90);
//            colorMode(RGB, 255);
//          } else {
//            pointColor = color(0); // Black lines when rainbow is off
//          }
          
//          // Draw point only if showCurrentPose is true
//          if (showCurrentPose) {
//            fill(pointColor);
//            stroke(0);
//            strokeWeight(1);
            
//            float size = 8;
//            if (pointName.contains("wrist") || pointName.equals("nose")) {
//              size = 12; // Highlight hands and face
//            }
            
//            ellipse(point.x, point.y, size, size);
//          }
//        }
//      }
//    }
//  }
//}

//void drawPoseConnections() {
//  // Define bone connections
//  String[][] connections = {
//    {"left_shoulder", "right_shoulder"},
//    {"left_shoulder", "left_elbow"},
//    {"right_shoulder", "right_elbow"},
//    {"left_elbow", "left_wrist"},
//    {"right_elbow", "right_wrist"},
//    {"left_shoulder", "left_hip"},
//    {"right_shoulder", "right_hip"},
//    {"left_hip", "right_hip"},
//    {"left_hip", "left_knee"},
//    {"right_hip", "right_knee"},
//    {"left_knee", "left_ankle"},
//    {"right_knee", "right_ankle"}
//  };
  
//  for (String[] connection : connections) {
//    drawConnection(connection[0], connection[1]);
//  }
//}

//void drawConnection(String point1Name, String point2Name) {
//  int idx1 = findPointIndex(point1Name);
//  int idx2 = findPointIndex(point2Name);
  
//  if (idx1 >= 0 && idx2 >= 0) {
//    ArrayList<PVector> traj1 = bodyTrajectories.get(idx1);
//    ArrayList<PVector> traj2 = bodyTrajectories.get(idx2);
    
//    if (currentFrame < traj1.size() && currentFrame < traj2.size()) {
//      PVector p1 = traj1.get(currentFrame);
//      PVector p2 = traj2.get(currentFrame);
      
//      if (p1 != null && p2 != null) {
//        line(p1.x, p1.y, p2.x, p2.y);
//      }
//    }
//  }
//}

//int findPointIndex(String pointName) {
//  for (int i = 0; i < trackedPoints.length; i++) {
//    if (trackedPoints[i].equals(pointName)) {
//      return i;
//    }
//  }
//  return -1;
//}

//void drawUI() {
//  // Semi-transparent background for UI
//  fill(0, 0, 0, 150);
//  rect(10, height - 120, 300, 110);
  
//  // UI text
//  fill(0, 0, 100);
//  textSize(12);
//  text("Frame: " + currentFrame + "/" + totalFrames, 20, height - 100);
//  text("Speed: " + nf(playbackSpeed, 1, 1) + "x", 20, height - 85);
//  text("Trail Length: " + trailLength, 20, height - 70);
//  text("Playing: " + (isPlaying ? "YES" : "NO"), 20, height - 55);
//  text("Trails: " + (showTrails ? "ON" : "OFF"), 20, height - 40);
//  text("Pose: " + (showCurrentPose ? "ON" : "OFF"), 20, height - 25);
  
//  // Progress bar
//  stroke(0, 0, 100);
//  strokeWeight(2);
//  line(20, height - 10, 280, height - 10);
  
//  if (totalFrames > 0) {
//    float progress = map(currentFrame, 0, totalFrames - 1, 20, 280);
//    fill(180, 80, 90);
//    ellipse(progress, height - 10, 8, 8);
//  }
//}

//// Keyboard controls
//void keyPressed() {
//  switch(key) {
//    case ' ':
//      isPlaying = !isPlaying;
//      break;
//    case 'r':
//    case 'R':
//      currentFrame = 0;
//      break;
//    case 't':
//    case 'T':
//      showTrails = !showTrails;
//      break;
//    case 'p':
//    case 'P':
//      showCurrentPose = !showCurrentPose;
//      break;
//    case 's':
//    case 'S':
//      saveFrame("dance-frame-####.png");
//      println("Frame saved!");
//      break;
//    case 'c':
//    case 'C':
//      background(232, 213, 188); // Reset to cream background
//      break;
//    case 'b':
//    case 'B':
//      rainbow = !rainbow;
//      break;
//  }
  
//  // Number keys for trail length
//  if (key >= '1' && key <= '9') {
//    trailLength = (key - '0') * 20;
//  }
  
//  // Arrow keys
//  if (keyCode == UP) {
//    playbackSpeed = min(playbackSpeed + 0.2, 3.0);
//  } else if (keyCode == DOWN) {
//    playbackSpeed = max(playbackSpeed - 0.2, 0.2);
//  } else if (keyCode == LEFT && currentFrame > 0) {
//    currentFrame--;
//    isPlaying = false;
//  } else if (keyCode == RIGHT && currentFrame < totalFrames - 1) {
//    currentFrame++;
//    isPlaying = false;
//  }
//}

//// Mouse controls for scrubbing
//void mousePressed() {
//  if (mouseY > height - 20 && mouseY < height && mouseX > 20 && mouseX < 280) {
//    float newFrame = map(mouseX, 20, 280, 0, totalFrames - 1);
//    currentFrame = constrain(int(newFrame), 0, totalFrames - 1);
//    isPlaying = false;
//  }
//}

//void mouseDragged() {
//  mousePressed(); // Allow scrubbing by dragging
//}

// Global variables
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
int fadeFrames = 60;
float time = 0;
boolean rainbow = false;
boolean kandinskyMode = false;

void setup() {
  size(1200, 800);
  colorMode(RGB, 255);
  background(232, 213, 188); // #E8D5BC
  
  // Load trajectory data
  loadTrajectoryData("cunningham_trajectories.json");
  
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
  // Create fade effect
  fill(232, 213, 188, 20);
  rect(0, 0, width, height);
  
  if (trajectoryData != null) {
    // Update animation
    if (isPlaying && currentFrame < totalFrames - 1) {
      currentFrame += int(playbackSpeed);
      if (currentFrame >= totalFrames) currentFrame = totalFrames - 1;
    }
    
    // Draw trajectories
    if (showTrails) {
      drawTrajectoryTrails();
    }
    
    // Draw current pose
    if (showCurrentPose) {
      drawCurrentPose();
    }
    
    // Draw UI
    drawUI();
  }
  
  time += 0.02;
}

void loadTrajectoryData(String filename) {
  try {
    trajectoryData = loadJSONObject(filename);
    
    if (trajectoryData != null) {
      // Get metadata
      JSONObject metadata = trajectoryData.getJSONObject("metadata");
      totalFrames = metadata.getInt("total_frames");
      
      // Get tracked points
      JSONArray pointsArray = metadata.getJSONArray("tracked_points");
      trackedPoints = new String[pointsArray.size()];
      for (int i = 0; i < pointsArray.size(); i++) {
        trackedPoints[i] = pointsArray.getString(i);
      }
      
      // Parse trajectory data
      bodyTrajectories = new ArrayList<ArrayList<PVector>>();
      JSONObject trajectories = trajectoryData.getJSONObject("trajectories");
      
      // Initialize trajectory lists
      for (int i = 0; i < trackedPoints.length; i++) {
        bodyTrajectories.add(new ArrayList<PVector>());
      }
      
      // Parse each frame
      for (int frame = 0; frame < totalFrames; frame++) {
        if (trajectories.hasKey(str(frame))) {
          JSONObject frameData = trajectories.getJSONObject(str(frame));
          JSONObject points = frameData.getJSONObject("points");
          
          for (int i = 0; i < trackedPoints.length; i++) {
            String pointName = trackedPoints[i];
            if (points.hasKey(pointName)) {
              JSONObject point = points.getJSONObject(pointName);
              float x = point.getFloat("x");
              float y = point.getFloat("y");
              float z = point.getFloat("z");
              
              bodyTrajectories.get(i).add(new PVector(x, y, z));
            } else {
              // Add null point for missing data
              bodyTrajectories.get(i).add(null);
            }
          }
        }
      }
      
      println("Loaded " + totalFrames + " frames of trajectory data");
    }
  } catch (Exception e) {
    println("Could not load trajectory data. Make sure 'dance_trajectories.json' is in the sketch folder.");
    println("Error: " + e.getMessage());
  }
}

color getBodyPartColor(String pointName) {
  // Return colors for different body parts
  if (pointName.equals("left_wrist")) return color(0, 80, 90);      // Red
  if (pointName.equals("right_wrist")) return color(20, 80, 90);    // Orange
  if (pointName.equals("left_elbow")) return color(60, 80, 80);     // Yellow
  if (pointName.equals("right_elbow")) return color(80, 80, 80);    // Light Green
  if (pointName.equals("left_shoulder")) return color(120, 80, 90); // Green
  if (pointName.equals("right_shoulder")) return color(160, 80, 90); // Teal
  if (pointName.equals("left_hip")) return color(200, 80, 80);      // Blue
  if (pointName.equals("right_hip")) return color(220, 80, 80);     // Deep Blue
  if (pointName.equals("left_knee")) return color(260, 80, 70);     // Purple
  if (pointName.equals("right_knee")) return color(280, 80, 70);    // Magenta
  if (pointName.equals("left_ankle")) return color(300, 80, 80);    // Pink
  if (pointName.equals("right_ankle")) return color(320, 80, 80);   // Rose
  if (pointName.equals("nose")) return color(40, 80, 95);           // Bright Yellow
  if (pointName.equals("left_heel")) return color(340, 80, 75);     // Deep Pink
  if (pointName.equals("right_heel")) return color(350, 80, 75);    // Red Pink
  
  // Default color
  return color(180, 60, 80);
}

void drawTrajectoryTrails() {
  for (int i = 0; i < trackedPoints.length; i++) {
    String pointName = trackedPoints[i];
    ArrayList<PVector> trajectory = bodyTrajectories.get(i);
    
    if (trajectory.size() > 1) {
      // Get color for this body part
      color pointColor;
      if (rainbow) {
        colorMode(HSB, 360, 100, 100);
        pointColor = color((frameCount + pointName.hashCode()) % 360, 80, 90);
        colorMode(RGB, 255);
      } else {
        pointColor = color(0); // Black lines when rainbow is off
      }
      
      // Draw trail
      int startFrame = max(0, currentFrame - trailLength);
      int endFrame = min(currentFrame, trajectory.size() - 1);
      
      if (kandinskyMode) {
        drawKandinskyStyle(trajectory, startFrame, endFrame, pointColor);
      } else {
        drawRegularTrail(trajectory, startFrame, endFrame, pointColor);
      }
    }
  }
}

void drawRegularTrail(ArrayList<PVector> trajectory, int startFrame, int endFrame, color pointColor) {
  for (int j = startFrame; j < endFrame; j++) {
    PVector current = trajectory.get(j);
    PVector next = trajectory.get(j + 1);
    
    if (current != null && next != null) {
      // Calculate alpha based on how recent the point is
      float alpha = map(j, startFrame, endFrame, 10, 100);
      
      // Calculate stroke weight based on velocity
      float distance = PVector.dist(current, next);
      float weight = map(distance, 0, 50, 0.5, strokeWeight * 3);
      weight = constrain(weight, 0.5, 6);
      
      // Set style
      stroke(pointColor);
      strokeWeight(weight);
      
      // Draw line segment
      line(current.x, current.y, next.x, next.y);
      
      // Add particle effects for fast movements
      if (distance > 20) {
        drawMotionParticle(current, next, pointColor);
      }
    }
  }
}

void drawKandinskyStyle(ArrayList<PVector> trajectory, int startFrame, int endFrame, color pointColor) {
  // Kandinsky-inspired drawing with curves, varying weights, and geometric elements
  
  for (int j = startFrame; j < endFrame - 2; j++) {
    PVector p1 = trajectory.get(j);
    PVector p2 = trajectory.get(j + 1);
    PVector p3 = trajectory.get(j + 2);
    
    if (p1 != null && p2 != null && p3 != null) {
      float distance = PVector.dist(p1, p2);
      
      // Varying line weights like Kandinsky
      float weight = map(distance, 0, 50, 1, 8);
      weight = constrain(weight, 1, 12);
      
      // Add organic curve variation
      float tension = map(sin(j * 0.1 + time), -1, 1, 0.1, 0.9);
      
      stroke(pointColor);
      strokeWeight(weight);
      noFill();
      
      // Draw flowing bezier curves instead of straight lines
      bezier(p1.x, p1.y, 
             lerp(p1.x, p2.x, tension), lerp(p1.y, p2.y, tension),
             lerp(p2.x, p3.x, 1-tension), lerp(p2.y, p3.y, 1-tension),
             p3.x, p3.y);
      
      // Add Kandinsky-style geometric elements at movement peaks
      if (distance > 25) {
        drawKandinskyElements(p2, distance, pointColor);
      }
      
      // Add line quality variation - sometimes dotted, sometimes solid
      if (distance < 10 && random(1) < 0.3) {
        drawDottedLine(p1, p2, pointColor);
      }
    }
  }
}

void drawKandinskyElements(PVector pos, float intensity, color lineColor) {
  pushMatrix();
  translate(pos.x, pos.y);
  
  float size = map(intensity, 20, 50, 5, 25);
  
  // Random geometric elements like Kandinsky used
  int elementType = int(random(4));
  
  stroke(lineColor);
  strokeWeight(2);
  
  switch(elementType) {
    case 0: // Circle
      noFill();
      ellipse(0, 0, size, size);
      break;
    case 1: // Triangle
      noFill();
      triangle(-size/2, size/3, size/2, size/3, 0, -size/2);
      break;
    case 2: // Small radiating lines
      for (int i = 0; i < 6; i++) {
        float angle = i * PI / 3;
        float lineLen = size/3;
        line(0, 0, cos(angle) * lineLen, sin(angle) * lineLen);
      }
      break;
    case 3: // Small arc
      noFill();
      arc(0, 0, size, size, 0, PI);
      break;
  }
  
  popMatrix();
}

void drawDottedLine(PVector start, PVector end, color c) {
  stroke(c);
  strokeWeight(3);
  
  float distance = PVector.dist(start, end);
  int dots = int(distance / 5);
  
  for (int i = 0; i <= dots; i++) {
    float t = i / float(dots);
    float x = lerp(start.x, end.x, t);
    float y = lerp(start.y, end.y, t);
    point(x, y);
  }
}

void drawMotionParticle(PVector start, PVector end, color c) {
  // Removed particle drawing to keep lines clean
  // Particles were creating dots that interfere with smooth lines
}

void drawCurrentPose() {
  // This function is now empty - no pose drawing at all
  // Keep the function for backwards compatibility with the toggle
}

void drawPoseConnections() {
  // Define bone connections
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
  
  for (String[] connection : connections) {
    drawConnection(connection[0], connection[1]);
  }
}

void drawConnection(String point1Name, String point2Name) {
  int idx1 = findPointIndex(point1Name);
  int idx2 = findPointIndex(point2Name);
  
  if (idx1 >= 0 && idx2 >= 0) {
    ArrayList<PVector> traj1 = bodyTrajectories.get(idx1);
    ArrayList<PVector> traj2 = bodyTrajectories.get(idx2);
    
    if (currentFrame < traj1.size() && currentFrame < traj2.size()) {
      PVector p1 = traj1.get(currentFrame);
      PVector p2 = traj2.get(currentFrame);
      
      if (p1 != null && p2 != null) {
        line(p1.x, p1.y, p2.x, p2.y);
      }
    }
  }
}

int findPointIndex(String pointName) {
  for (int i = 0; i < trackedPoints.length; i++) {
    if (trackedPoints[i].equals(pointName)) {
      return i;
    }
  }
  return -1;
}

void drawUI() {
  // Semi-transparent background for UI
  fill(0, 0, 0, 150);
  rect(10, height - 120, 300, 110);
  
  // UI text
  fill(0, 0, 100);
  textSize(12);
  text("Frame: " + currentFrame + "/" + totalFrames, 20, height - 100);
  text("Speed: " + nf(playbackSpeed, 1, 1) + "x", 20, height - 85);
  text("Trail Length: " + trailLength, 20, height - 70);
  text("Playing: " + (isPlaying ? "YES" : "NO"), 20, height - 55);
  text("Trails: " + (showTrails ? "ON" : "OFF"), 20, height - 40);
  text("Pose: " + (showCurrentPose ? "ON" : "OFF"), 20, height - 25);
  
  // Progress bar
  stroke(0, 0, 100);
  strokeWeight(2);
  line(20, height - 10, 280, height - 10);
  
  if (totalFrames > 0) {
    float progress = map(currentFrame, 0, totalFrames - 1, 20, 280);
    fill(180, 80, 90);
    ellipse(progress, height - 10, 8, 8);
  }
}

// Keyboard controls
void keyPressed() {
  switch(key) {
    case ' ':
      isPlaying = !isPlaying;
      break;
    case 'r':
    case 'R':
      currentFrame = 0;
      break;
    case 't':
    case 'T':
      showTrails = !showTrails;
      break;
    case 'p':
    case 'P':
      showCurrentPose = !showCurrentPose;
      break;
    case 's':
    case 'S':
      saveFrame("dance-frame-####.png");
      println("Frame saved!");
      break;
    case 'c':
    case 'C':
      background(232, 213, 188); // Reset to cream background
      break;
    case 'b':
    case 'B':
      rainbow = !rainbow;
      break;
    case 'k':
    case 'K':
      kandinskyMode = !kandinskyMode;
      println("Kandinsky mode: " + (kandinskyMode ? "ON" : "OFF"));
      break;
  }
  
  // Number keys for trail length
  if (key >= '1' && key <= '9') {
    trailLength = (key - '0') * 20;
  }
  
  // Arrow keys
  if (keyCode == UP) {
    playbackSpeed = min(playbackSpeed + 0.2, 3.0);
  } else if (keyCode == DOWN) {
    playbackSpeed = max(playbackSpeed - 0.2, 0.2);
  } else if (keyCode == LEFT && currentFrame > 0) {
    currentFrame--;
    isPlaying = false;
  } else if (keyCode == RIGHT && currentFrame < totalFrames - 1) {
    currentFrame++;
    isPlaying = false;
  }
}

// Mouse controls for scrubbing
void mousePressed() {
  if (mouseY > height - 20 && mouseY < height && mouseX > 20 && mouseX < 280) {
    float newFrame = map(mouseX, 20, 280, 0, totalFrames - 1);
    currentFrame = constrain(int(newFrame), 0, totalFrames - 1);
    isPlaying = false;
  }
}

void mouseDragged() {
  mousePressed(); // Allow scrubbing by dragging
}
