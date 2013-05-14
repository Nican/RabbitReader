SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

CREATE SCHEMA IF NOT EXISTS `rreader` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci ;
USE `rreader` ;

-- -----------------------------------------------------
-- Table `rreader`.`feed`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `rreader`.`feed` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `title` VARCHAR(64) NOT NULL ,
  `link` VARCHAR(128) NOT NULL ,
  `description` TEXT NOT NULL ,
  `last_update` DATETIME NULL ,
  `feedURL` VARCHAR(128) NOT NULL ,
  `disabled` TINYINT(1) NULL DEFAULT 0 ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `feedURL_UNIQUE` (`feedURL` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `rreader`.`feed_entry`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `rreader`.`feed_entry` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `feed_id` INT UNSIGNED NOT NULL ,
  `title` TINYTEXT NOT NULL ,
  `content` TEXT NOT NULL ,
  `published` VARCHAR(64) NOT NULL ,
  `updated` DATETIME NOT NULL ,
  `author` VARCHAR(64) NOT NULL ,
  `link` TEXT NOT NULL ,
  `guid` VARCHAR(128) NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `parentFeed_idx` (`feed_id` ASC) ,
  INDEX `feed_entry_guid` USING BTREE (`guid` ASC) ,
  CONSTRAINT `parentFeed`
    FOREIGN KEY (`feed_id` )
    REFERENCES `rreader`.`feed` (`id` )
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `rreader`.`users`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `rreader`.`users` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `name` VARCHAR(45) NULL ,
  `last_access` TIMESTAMP NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `name_UNIQUE` (`name` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `rreader`.`user_feed`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `rreader`.`user_feed` (
  `user_id` INT UNSIGNED NOT NULL ,
  `feed_id` INT UNSIGNED NOT NULL ,
  `newest_read` DATETIME NOT NULL COMMENT 'All items before this date will be marked as read. ' ,
  `unread_items` INT UNSIGNED NULL ,
  `priority` INT UNSIGNED NOT NULL DEFAULT 0 ,
  `group` VARCHAR(64) NOT NULL ,
  PRIMARY KEY (`user_id`, `feed_id`) ,
  INDEX `parentFeed_idx` (`feed_id` ASC) ,
  INDEX `parentUser_idx` (`user_id` ASC) ,
  INDEX `groupIndex` (`group` ASC, `user_id` ASC) ,
  CONSTRAINT `parentUserFeed`
    FOREIGN KEY (`feed_id` )
    REFERENCES `rreader`.`feed` (`id` )
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `parentFeedUser`
    FOREIGN KEY (`user_id` )
    REFERENCES `rreader`.`users` (`id` )
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `rreader`.`user_feed_readitems`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `rreader`.`user_feed_readitems` (
  `user_id` INT UNSIGNED NOT NULL ,
  `entry_id` INT UNSIGNED NOT NULL ,
  PRIMARY KEY (`user_id`, `entry_id`) ,
  INDEX `readitems_user_idx` (`user_id` ASC) ,
  INDEX `readitems_feed_entry_idx` (`entry_id` ASC) ,
  CONSTRAINT `readitems_user`
    FOREIGN KEY (`user_id` )
    REFERENCES `rreader`.`users` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `readitems_feed_entry`
    FOREIGN KEY (`entry_id` )
    REFERENCES `rreader`.`feed_entry` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `rreader`.`user_entry_label`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `rreader`.`user_entry_label` (
  `user_id` INT UNSIGNED NOT NULL ,
  `feed_entry_id` INT UNSIGNED NOT NULL ,
  `label` VARCHAR(45) NULL ,
  INDEX `user_feed_readitems-user_idx` (`user_id` ASC) ,
  INDEX `user_feed_readitems-entry_idx` (`feed_entry_id` ASC) ,
  PRIMARY KEY (`user_id`, `feed_entry_id`) ,
  CONSTRAINT `user_feed_readitems-user`
    FOREIGN KEY (`user_id` )
    REFERENCES `rreader`.`users` (`id` )
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `user_feed_readitems-entry`
    FOREIGN KEY (`feed_entry_id` )
    REFERENCES `rreader`.`feed_entry` (`id` )
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;

USE `rreader` ;

-- -----------------------------------------------------
-- Placeholder table for view `rreader`.`entrylist`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `rreader`.`entrylist` (`id` INT, `title` INT, `published` INT, `updated` INT, `link` INT, `author` INT, `feedtitle` INT, `feedid` INT, `userid` INT, `group` INT, `is_read` INT, `label` INT);

-- -----------------------------------------------------
-- Placeholder table for view `rreader`.`home_view`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `rreader`.`home_view` (`id` INT, `title` INT, `link` INT, `description` INT, `last_update` INT, `user_id` INT, `group` INT, `priority` INT, `unread` INT);

-- -----------------------------------------------------
-- Placeholder table for view `rreader`.`unread_view`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `rreader`.`unread_view` (`feed_id` INT, `user_id` INT, `unread` INT);

-- -----------------------------------------------------
-- procedure update_unread
-- -----------------------------------------------------

DELIMITER $$
USE `rreader`$$
CREATE PROCEDURE `rreader`.`update_unread` ()
BEGIN
UPDATE user_feed 
JOIN unread_view ON user_feed.user_id=unread_view.user_id AND user_feed.feed_id=unread_view.feed_id 
SET  user_feed.unread_items=unread_view.unread;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- View `rreader`.`entrylist`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rreader`.`entrylist`;
USE `rreader`;
CREATE  OR REPLACE VIEW `rreader`.`entrylist` AS
SELECT entry.id, entry.title, entry.published, entry.updated, entry.link, entry.author, 
feed.title as `feedtitle`, feed.id AS `feedid`, user_feed.user_id as `userid`, `user_feed`.`group`, 
	(`user_feed`.`newest_read` > `entry`.`updated` OR `user_feed_readitems`.`entry_id` IS NOT NULL) as `is_read`,
	`user_entry_label`.`label` as `label`
FROM `feed_entry` as `entry`
JOIN `feed` ON `entry`.`feed_id` = `feed`.`id` 
JOIN `user_feed` ON `feed`.`id` = user_feed.feed_id 
LEFT JOIN `user_feed_readitems` ON 
	`user_feed`.`user_id` = `user_feed_readitems`.`user_id` AND
	`entry`.`id` = `user_feed_readitems`.`entry_id`
LEFT JOIN `user_entry_label` ON
	`user_entry_label`.`user_id` = `user_feed`.`user_id` AND
	`user_entry_label`.`feed_entry_id` = `entry`.`id`;

-- -----------------------------------------------------
-- View `rreader`.`home_view`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rreader`.`home_view`;
USE `rreader`;
CREATE  OR REPLACE VIEW `rreader`.`home_view` AS
SELECT feed.id , feed.title, feed.link, feed.description, feed.last_update, user_feed.user_id,user_feed.group as `group`, user_feed.priority,
`user_feed`.`unread_items` as `unread`
FROM feed  
JOIN user_feed ON feed.id = user_feed.feed_id 
ORDER BY user_feed.priority, feed.title
;

-- -----------------------------------------------------
-- View `rreader`.`unread_view`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rreader`.`unread_view`;
USE `rreader`;
CREATE  OR REPLACE VIEW `rreader`.`unread_view` AS
SELECT 
	`user_feed`.`feed_id` AS `feed_id`, 
	user_feed.user_id as `user_id`, 
	COUNT(IF(`user_feed_readitems`.`entry_id` IS NULL AND `entry`.`updated` > `user_feed`.`newest_read`, 1,NULL)) as `unread`
FROM `user_feed` 
JOIN `feed_entry` as `entry` ON `user_feed`.`feed_id` = entry.feed_id 
LEFT JOIN `user_feed_readitems` ON 
	`user_feed`.`user_id` = `user_feed_readitems`.`user_id` AND
	`entry`.`id` = `user_feed_readitems`.`entry_id`
GROUP BY `user_feed`.`user_id`, `user_feed`.`feed_id`;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
