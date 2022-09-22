CREATE TABLE IF NOT EXISTS suggestions_channels (
    guild_id TEXT PRIMARY KEY,
    id TEXT
);

CREATE TABLE IF NOT EXISTS role_permissions (
    guild_id TEXT,
    id TEXT,
    permission_name TEXT
);

CREATE TABLE IF NOT EXISTS bot_channels_enabled (
    guild_id TEXT PRIMARY KEY,
    is_enabled BOOLEAN
);

CREATE TABLE IF NOT EXISTS bot_channels (
    guild_id TEXT,
    id TEXT
);

CREATE TABLE IF NOT EXISTS special_channels (
    guild_id TEXT,
    id TEXT,
    channel_name TEXT
);

CREATE TABLE IF NOT EXISTS arena_bans (
    guild_id TEXT,
    id TEXT
);

CREATE TABLE IF NOT EXISTS prefixes (
    guild_id TEXT PRIMARY KEY,
    prefix TEXT
);

CREATE TABLE IF NOT EXISTS players (
    guild_id TEXT,
    id TEXT,
    elo REAL,
    wins REAL,
    losses REAL,
    arena_wins REAL
);

CREATE TABLE IF NOT EXISTS rank_roles (
    guild_id TEXT,
    id TEXT,
    position REAL
);

CREATE TABLE IF NOT EXISTS elo (
    guild_id TEXT PRIMARY KEY,
    k_factor REAL,
    scale REAL
)