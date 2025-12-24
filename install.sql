CREATE TABLE IF NOT EXISTS `tablet_darknet_rep` (
  `tablet_serial` varchar(50) NOT NULL,
  `reputation` int(11) DEFAULT 0,
  PRIMARY KEY (`tablet_serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `darknet_custom_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `creator_serial` varchar(50) NOT NULL,
  `worker_serial` varchar(50) DEFAULT NULL,
  `title` varchar(100) NOT NULL,
  `description` text NOT NULL,
  `reward` int(11) NOT NULL DEFAULT 0,
  `status` varchar(20) DEFAULT 'open', -- 'open', 'active', 'completed'
  `created_at` timestamp DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `darknet_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job_id` int(11) NOT NULL,
  `sender_serial` varchar(50) NOT NULL,
  `message` text NOT NULL,
  `created_at` timestamp DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `job_id` (`job_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;