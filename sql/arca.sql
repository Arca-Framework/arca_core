CREATE TABLE IF NOT EXISTS `players` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(16) NOT NULL,
    `cid` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `license` VARCHAR(60) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `money` LONGTEXT NOT NULL,
    `charinfo` LONGTEXT NOT NULL,
    `job` LONGTEXT NOT NULL,
    `gang` LONGTEXT NOT NULL,
    `position` LONGTEXT NOT NULL,
    `metadata` LONGTEXT NOT NULL,
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizenid` (`citizenid`),
    KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- used by arca_character for illenium-appearance (qb-compatible layout)
CREATE TABLE IF NOT EXISTS `playerskins` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(16) NOT NULL,
    `model` VARCHAR(255) NOT NULL,
    `skin` TEXT NOT NULL,
    `active` TINYINT NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
