(ros::roseus "pepper")

(load "package://peppereus/pepper.l")
(load "package://pr2eus/robot-interface.l")
(ros::load-ros-manifest "jsk_pepper_startup")
(ros::load-ros-manifest "peppereus")

(defclass naoqi-interface
  :super robot-interface
  :slots (joint-stiffness-trajectory-action)
  )

(defmethod naoqi-interface
  (:init
   (&rest args &key (robot) (type :naoqi-controller) &allow-other-keys)
   (send-super* :init :robot robot :type type :groupname "naoqi_interface" args)
   (ros::advertise "cmd_pose" geometry_msgs::Pose2D 1)
   (ros::advertise "cmd_vel" geometry_msgs::Twist 1)
   (ros::advertise "speech" std_msgs::String 1)
   (ros::advertise "joint_angles" nao_msgs::JointAnglesWithSpeed 1)
   (setq joint-stiffness-trajectory-action
	 (instance ros::simple-action-client :init
		   "joint_stiffness_trajectory"
		   naoqi_msgs::JointTrajectoryAction))
   self)
  ;;
  (:naoqi-controller
   ()
   (list
    (list
     (cons :controller-action "joint_trajectory")
    ;;(cons :controller-state "joint_trajectory")
     (cons :controller-state "dummy_state") ;; this is dummy
     (cons :action-type nao_msgs::JointTrajectoryAction)
     (cons :joint-names (mapcar #'(lambda (n) (if (symbolp n) (symbol-name n) n)) (send-all (send robot :joint-list) :name))))
    ))
  ;;
  (:servo-on () (send self :send-stiffness-controller 1.0))
  (:servo-off () (send self :send-stiffness-controller 0.0))
  (:send-stiffness-controller
   (stiffness)
   (let ((goal (send joint-stiffness-trajectory-action :make-goal-instance))
	 (joint-names (mapcar #'(lambda (n) (if (symbolp n) (symbol-name n) n)) (send-all (send robot :joint-list) :name))))
     (send goal :header :seq 1)
     (send goal :header :stamp (ros::time-now))
     (setq joint-names (append joint-names (list "RHand" "LHand")))
     (send goal :goal :trajectory :joint_names joint-names)
     (send goal :goal :trajectory :header :stamp (ros::time-now))
     (send goal :goal :trajectory :points
	   (list (instance trajectory_msgs::JointTrajectoryPoint
			   :init
			   :positions (fill (instantiate float-vector (length joint-names)) stiffness)
			   :time_from_start (ros::time 1))))
     (send joint-stiffness-trajectory-action :send-goal goal)
     ))
  ;;
  (:move-hand
   (value &optional (arm :arms))
   (let ((start_grasp_msg (instance nao_msgs::JointAnglesWithSpeed :init)))
     (send start_grasp_msg :header :stamp (ros::time-now))
     (send start_grasp_msg :header :seq 1)
     (send start_grasp_msg :speed 0.5)
     (send start_grasp_msg :relative 0)
     (case arm  
       (:arms
	(send start_grasp_msg :joint_names (list "RHand" "LHand"))
	(send start_grasp_msg :joint_angles (list value value)))
       (:rarm 
	(send start_grasp_msg :joint_names (list "RHand"))
	(send start_grasp_msg :joint_angles (list value)))
       (:larm 
	(send start_grasp_msg :joint_names (list "LHand"))
	(send start_grasp_msg :joint_angles (list value))))
     (ros::publish "joint_angles" start_grasp_msg)
     ))
  (:start-grasp
   (&optional (arm :arms))
   (send self :move-hand 0.0 arm)
   )
  (:stop-grasp
   (&optional (arm :arms))
   (send self :move-hand 1.0 arm)
   )
  ;;
  (:go-pos
   (x y &optional (d 0)) ;; [m] [m] [degree]
   (let ((pose_msg (instance geometry_msgs::Pose2D :init)))
     (send pose_msg :x x)
     (send pose_msg :y y)
     (send pose_msg :theta (deg2rad d))
     (ros::publish (if namespace (format nil "~A/cmd_pose" namespace) "cmd_pose") pose_msg)
     ))

  (:go-velocity
   (x y d &optional (msec 1000) &key (stop t)) ;; [m/sec] [m/sec] [rad/sec]
   (let ((vel_msg (instance geometry_msgs::Twist :init)))
     (when (> (abs x) 1)
       (ros::ros-error "x must be in range [-1 <-> 1]")
       (return-from :go-velocity nil))
     (when (> (abs y) 1)
       (ros::ros-error "y must be in range [-1 <-> 1]")
       (return-from :go-velocity nil))
     (when (> (abs d) 1)
       (ros::ros-error "theta must be in range [-1 <-> 1]")
       (return-from :go-velocity nil))
     (send vel_msg :linear :x x)
     (send vel_msg :linear :y y)
     (send vel_msg :angular :z d)
     (ros::publish (if namespace (format nil "~A/cmd_vel" namespace) "cmd_vel") vel_msg)
     (when stop
       (unix:usleep (* 1000 msec))
       (send self :go-stop)
       )
     ))
  (:go-stop
   ()
   (send self :go-velocity 0 0 0 0 :stop nil))
  )

;;
(defclass pepper-interface
  :super naoqi-interface
  :slots ()
  )

(defmethod pepper-interface
  (:init (&rest args)
   (send-super* :init :robot pepper-robot args))
  (:servo-on () (call-empty-service "wakeup"))
  (:servo-off () (call-empty-service "rest"))
  )

(defmethod pepper-robot
  (:reset-pose () (send self :angle-vector #f(2 -2 -5 85 10 -70 -20 -40 85 -10  70  20  40 0 -0)))
  )


#|
(setq *ri* (instance pepper-interface :init))
(setq *pepper* (pepper))
(send *pepper* :reset-pose)
(send *ri* :angle-vector (send *pepper* :angle-vector) 2000)
|#