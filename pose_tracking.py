import cv2
import mediapipe as mp
import numpy as np
import json
import time
from collections import defaultdict

class DanceTracker:
    def __init__(self, save_data=True):
        # Initialize MediaPipe pose detection
        self.mp_pose = mp.solutions.pose
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=2,  # Higher accuracy
            enable_segmentation=False,
            min_detection_confidence=0.7,
            min_tracking_confidence=0.5
        )
        self.mp_draw = mp.solutions.drawing_utils
        
        # Data storage
        self.save_data = save_data
        self.trajectory_data = defaultdict(list)
        self.frame_count = 0
        self.start_time = time.time()
        
        # Key body parts we want to track (MediaPipe landmark indices)
        self.key_points = {
            'left_wrist': 15,
            'right_wrist': 16,
            'left_elbow': 13,
            'right_elbow': 14,
            'left_shoulder': 11,
            'right_shoulder': 12,
            'left_hip': 23,
            'right_hip': 24,
            'left_knee': 25,
            'right_knee': 26,
            'left_ankle': 27,
            'right_ankle': 28,
            'nose': 0,
            'left_heel': 29,
            'right_heel': 30
        }
        
    def process_frame(self, frame):
        """Process a single frame and extract pose landmarks"""
        # Convert BGR to RGB
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Process the frame
        results = self.pose.process(rgb_frame)
        
        # Draw pose landmarks on frame
        if results.pose_landmarks:
            self.mp_draw.draw_landmarks(
                frame, 
                results.pose_landmarks, 
                self.mp_pose.POSE_CONNECTIONS,
                self.mp_draw.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=2),
                self.mp_draw.DrawingSpec(color=(0, 0, 255), thickness=2)
            )
            
            # Extract and store trajectory data
            if self.save_data:
                self.extract_trajectories(results.pose_landmarks, frame.shape)
        
        return frame, results
    
    def extract_trajectories(self, landmarks, frame_shape):
        """Extract trajectory data for key body parts"""
        h, w = frame_shape[:2]
        timestamp = time.time() - self.start_time
        
        frame_data = {
            'frame': self.frame_count,
            'timestamp': timestamp,
            'points': {}
        }
        
        for point_name, landmark_idx in self.key_points.items():
            if landmark_idx < len(landmarks.landmark):
                landmark = landmarks.landmark[landmark_idx]
                
                # Convert normalized coordinates to pixel coordinates
                x = int(landmark.x * w)
                y = int(landmark.y * h)
                z = landmark.z  # Relative depth
                visibility = landmark.visibility
                
                # Only store if landmark is visible enough
                if visibility > 0.5:
                    frame_data['points'][point_name] = {
                        'x': x,
                        'y': y,
                        'z': z,
                        'visibility': visibility
                    }
        
        self.trajectory_data[self.frame_count] = frame_data
        self.frame_count += 1
    
    def save_trajectory_data(self, filename='dance_trajectories.json'):
        """Save collected trajectory data to JSON file"""
        if not self.trajectory_data:
            print("No trajectory data to save")
            return
            
        # Convert defaultdict to regular dict for JSON serialization
        data_to_save = {
            'metadata': {
                'total_frames': self.frame_count,
                'duration': time.time() - self.start_time,
                'tracked_points': list(self.key_points.keys())
            },
            'trajectories': dict(self.trajectory_data)
        }
        
        with open(filename, 'w') as f:
            json.dump(data_to_save, f, indent=2)
        
        print(f"Trajectory data saved to {filename}")
        print(f"Captured {self.frame_count} frames over {data_to_save['metadata']['duration']:.2f} seconds")
    
    def run_webcam(self):
        """Run pose tracking on webcam feed"""
        cap = cv2.VideoCapture(0)
        
        print("Starting dance tracking... Press 'q' to quit, 's' to save data")
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Process frame
            processed_frame, results = self.process_frame(frame)
            
            # Display instructions
            cv2.putText(processed_frame, "Dance Tracking - Press 'q' to quit, 's' to save", 
                       (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(processed_frame, f"Frames captured: {self.frame_count}", 
                       (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
            
            # Show frame
            cv2.imshow('Dance Pose Tracking', processed_frame)
            
            # Handle key presses
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord('s'):
                self.save_trajectory_data()
        
        cap.release()
        cv2.destroyAllWindows()
        
        # Save data on exit if we have any
        if self.save_data and self.trajectory_data:
            self.save_trajectory_data()
    
    def run_on_video(self, video_path):
        """Run pose tracking on a video file"""
        cap = cv2.VideoCapture(video_path)
        
        # Get video properties
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        print(f"Processing video: {video_path}")
        print(f"FPS: {fps}, Total frames: {total_frames}")
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Process frame
            processed_frame, results = self.process_frame(frame)
            
            # Optional: display progress
            if self.frame_count % 30 == 0:  # Every 30 frames
                print(f"Processed {self.frame_count}/{total_frames} frames")
            
            # Optional: show video (comment out for faster processing)
            cv2.imshow('Dance Pose Tracking', processed_frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
        
        cap.release()
        cv2.destroyAllWindows()
        
        # Save data
        if self.save_data:
            video_name = video_path.split('/')[-1].split('.')[0]
            self.save_trajectory_data(f'{video_name}_trajectories.json')

# Example usage
if __name__ == "__main__":
    tracker = DanceTracker(save_data=True)
    
    # Choose your input method:
    
    # Option 1: Use webcam
    # tracker.run_webcam()
    
    # Option 2: Process a video file
    tracker.run_on_video('content/cunningham.mp4')