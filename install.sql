CREATE TABLE IF NOT EXISTS `player_darknet_rep` (
  `identifier` varchar(50) NOT NULL,
  `reputation` int(11) DEFAULT 0,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;