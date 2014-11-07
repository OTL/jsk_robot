#!/usr/bin/env roseus

(ros::load-ros-manifest "roseus")
(load "package://pr2eus/speak.l")
(ros::roseus "pepper_twitter")


(ros::advertise "/tweet" std_msgs::String 1)
;;(ros::advertise "robotsound_jp" sound_play::SoundRequest 5)

(defun tweet (str)
  ;; camera shot sound
;;  (ros::publish "robotsound_jp"
;;		(instance sound_play::SoundRequest :init
;;			  :sound sound_play::SoundRequest::*play_file*
;;			  :command sound_play::SoundRequest::*play_once*
;;			  :arg (ros::resolve-ros-path "package://jsk_pr2_startup/jsk_pr2_lifelog/camera.wav")))

  ;; save image sto /tmp/pepper_camera.jpg
  (ros::service-call "/image_saver/save" (instance std_srvs::EmptyRequest :init))
  (ros::sleep 3)
  (ros::ros-info "save image")
  ;; tweet
  (ros::publish "/tweet" (instance std_msgs::String :init :data (format nil "~A /tmp/pepper_camera.png" str)))
;;  (speak-jp "ついーとしました")
  (ros::ros-info "tweet ~A" str)
  )

;;