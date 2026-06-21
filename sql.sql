-- LK Inventory (lk_inv) — database schema
CREATE TABLE IF NOT EXISTS `lk_inventories` (
    `owner_id`   VARCHAR(80)  NOT NULL,
    `inv_type`   VARCHAR(40)  NOT NULL DEFAULT 'player',
    `slots_json` LONGTEXT     NULL,
    `last_saved` TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`owner_id`, `inv_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Periodic inventory snapshots used for anti-dupe rollback (/lk_rollback).
CREATE TABLE IF NOT EXISTS `lk_snapshots` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `owner_id`   VARCHAR(80)  NOT NULL,
    `taken_at`   TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP,
    `slots_json` LONGTEXT     NULL,
    PRIMARY KEY (`id`),
    KEY `owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
