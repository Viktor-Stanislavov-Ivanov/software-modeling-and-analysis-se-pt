-- =======================================================================================
-- Project: HiDiveDb (Database Modeling and Analysis Coursework)
-- Description: Complete DDL and DML script for creating the database, schemas, tables, 
--              programmability objects, and inserting sample data.
-- =======================================================================================

-- ---------------------------------------------------------------------------------------
-- 1. DATABASE & SCHEMAS CREATION
-- ---------------------------------------------------------------------------------------
USE [master];
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'HiDiveDb')
BEGIN
    CREATE DATABASE HiDiveDb;
END
GO

USE [HiDiveDb];
GO

CREATE SCHEMA [Accounts];
GO
CREATE SCHEMA [Content];
GO
CREATE SCHEMA [Engagement];
GO

-- ---------------------------------------------------------------------------------------
-- 2. TABLES & CONSTRAINTS CREATION
-- ---------------------------------------------------------------------------------------

CREATE TABLE [Accounts].[Subscriptions] (
    [TierId] INT IDENTITY(1,1) PRIMARY KEY,
    [TierName] VARCHAR(50) NOT NULL UNIQUE,
    [MonthlyPrice] DECIMAL(5,2) NOT NULL,
    [IsAdFree] BIT NOT NULL DEFAULT 0
);

CREATE TABLE [Accounts].[Users] (
    [UserId] INT IDENTITY(1,1) PRIMARY KEY,
    [TierId] INT NOT NULL,
    [Username] VARCHAR(50) NOT NULL UNIQUE,
    [Email] VARCHAR(100) NOT NULL UNIQUE,
    [PasswordHash] VARCHAR(255) NOT NULL,
    [DateOfBirth] DATE NOT NULL,
    [IsDeleted] BIT NOT NULL DEFAULT 0,
    [DeletedOn] DATETIME2(7) NULL,
    CONSTRAINT FK_Users_Subscriptions FOREIGN KEY ([TierId]) REFERENCES [Accounts].[Subscriptions]([TierId])
);

CREATE TABLE [Accounts].[UserDevices] (
    [DeviceId] INT IDENTITY(1,1) PRIMARY KEY,
    [UserId] INT NOT NULL,
    [DeviceName] NVARCHAR(50) NOT NULL,
    CONSTRAINT FK_UserDevices_Users FOREIGN KEY ([UserId]) REFERENCES [Accounts].[Users]([UserId])
);

CREATE TABLE [Content].[Genres] (
    [GenreId] INT IDENTITY(1,1) PRIMARY KEY,
    [Name] VARCHAR(50) NOT NULL UNIQUE,
    [Description] VARCHAR(255) NULL
);

CREATE TABLE [Content].[Animes] (
    [AnimeId] INT IDENTITY(1,1) PRIMARY KEY,
    [Title] VARCHAR(150) NOT NULL,
    [Synopsis] TEXT NULL,
    [Studio] VARCHAR(100) NULL,
    [ReleaseYear] INT NULL,
    [IsDeleted] BIT NOT NULL DEFAULT 0,
    [DeletedOn] DATETIME2(7) NULL
);

CREATE TABLE [Content].[AnimeGenres] (
    [AnimeId] INT NOT NULL,
    [GenreId] INT NOT NULL,
    PRIMARY KEY ([AnimeId], [GenreId]),
    CONSTRAINT FK_AnimeGenres_Animes FOREIGN KEY ([AnimeId]) REFERENCES [Content].[Animes]([AnimeId]),
    CONSTRAINT FK_AnimeGenres_Genres FOREIGN KEY ([GenreId]) REFERENCES [Content].[Genres]([GenreId])
);

CREATE TABLE [Content].[Episodes] (
    [EpisodeId] INT IDENTITY(1,1) PRIMARY KEY,
    [AnimeId] INT NOT NULL,
    [EpisodeNumber] INT NOT NULL,
    [Title] VARCHAR(150) NULL,
    [DurationMinutes] INT NOT NULL,
    CONSTRAINT FK_Episodes_Animes FOREIGN KEY ([AnimeId]) REFERENCES [Content].[Animes]([AnimeId])
);

CREATE TABLE [Engagement].[WatchHistory] (
    [HistoryId] INT IDENTITY(1,1) PRIMARY KEY,
    [UserId] INT NOT NULL,
    [EpisodeId] INT NOT NULL,
    [WatchDate] DATETIME2(7) NOT NULL DEFAULT GETDATE(),
    [StoppedAtMinute] INT NOT NULL,
    [IsCompleted] BIT NOT NULL DEFAULT 0,
    CONSTRAINT FK_WatchHistory_Users FOREIGN KEY ([UserId]) REFERENCES [Accounts].[Users]([UserId]),
    CONSTRAINT FK_WatchHistory_Episodes FOREIGN KEY ([EpisodeId]) REFERENCES [Content].[Episodes]([EpisodeId])
);

CREATE TABLE [Engagement].[Reviews] (
    [ReviewId] INT IDENTITY(1,1) PRIMARY KEY,
    [UserId] INT NOT NULL,
    [AnimeId] INT NOT NULL,
    [Score] INT NOT NULL CHECK ([Score] BETWEEN 1 AND 5),
    [Comment] VARCHAR(500) NULL,
    [ReviewDate] DATETIME2(7) NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Reviews_Users FOREIGN KEY ([UserId]) REFERENCES [Accounts].[Users]([UserId]),
    CONSTRAINT FK_Reviews_Animes FOREIGN KEY ([AnimeId]) REFERENCES [Content].[Animes]([AnimeId])
);

CREATE TABLE [Engagement].[Watchlists] (
    [WatchlistId] INT IDENTITY(1,1) PRIMARY KEY,
    [UserId] INT NOT NULL,
    [AnimeId] INT NOT NULL,
    [DateAdded] DATETIME2(7) NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Watchlists_Users FOREIGN KEY ([UserId]) REFERENCES [Accounts].[Users]([UserId]),
    CONSTRAINT FK_Watchlists_Animes FOREIGN KEY ([AnimeId]) REFERENCES [Content].[Animes]([AnimeId]),
    CONSTRAINT UQ_Watchlist UNIQUE ([UserId], [AnimeId])
);
GO

-- ---------------------------------------------------------------------------------------
-- 3. FUNCTIONS & STORED PROCEDURES
-- ---------------------------------------------------------------------------------------

-- Function: Calculate User's Age
CREATE FUNCTION [Accounts].[fn_CalculateUserAge] (@DateOfBirth DATE)
RETURNS INT
AS
BEGIN
    DECLARE @Age INT = DATEDIFF(YEAR, @DateOfBirth, GETDATE());
    IF (MONTH(@DateOfBirth) > MONTH(GETDATE())) OR (MONTH(@DateOfBirth) = MONTH(GETDATE()) AND DAY(@DateOfBirth) > DAY(GETDATE()))
    BEGIN
        SET @Age = @Age - 1;
    END
    RETURN @Age;
END;
GO

-- Function: Get the average review score for an Anime
CREATE FUNCTION [Engagement].[fn_GetAverageAnimeScore] (@AnimeId INT)
RETURNS DECIMAL(3,2)
AS
BEGIN
    DECLARE @AvgScore DECIMAL(3,2);
    SELECT @AvgScore = AVG(CAST(Score AS DECIMAL(4,2))) 
    FROM [Engagement].[Reviews] 
    WHERE AnimeId = @AnimeId;
    
    RETURN ISNULL(@AvgScore, 0.00);
END;
GO

-- Procedure: Register a new user
CREATE PROCEDURE [Accounts].[sp_RegisterNewUser]
    @Username VARCHAR(50),
    @Email VARCHAR(100),
    @PasswordHash VARCHAR(255),
    @DateOfBirth DATE
AS
BEGIN
    DECLARE @FreeTierId INT = (SELECT TierId FROM [Accounts].[Subscriptions] WHERE TierName = 'Free Tier');
    INSERT INTO [Accounts].[Users] (TierId, Username, Email, PasswordHash, DateOfBirth)
    VALUES (@FreeTierId, @Username, @Email, @PasswordHash, @DateOfBirth);
END;
GO

-- Procedure: Add anime to watchlist safely
CREATE PROCEDURE [Engagement].[sp_AddAnimeToWatchlist]
    @UserId INT,
    @AnimeId INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [Engagement].[Watchlists] WHERE UserId = @UserId AND AnimeId = @AnimeId)
    BEGIN
        INSERT INTO [Engagement].[Watchlists] (UserId, AnimeId)
        VALUES (@UserId, @AnimeId);
    END
END;
GO

-- ---------------------------------------------------------------------------------------
-- 4. TRIGGERS
-- ---------------------------------------------------------------------------------------

CREATE TRIGGER [Engagement].[TR_InsteadOfInsertReview]
ON [Engagement].[Reviews]
INSTEAD OF INSERT
AS
BEGIN
    -- Prevent duplicate reviews from the same user for the same anime
    IF EXISTS (
        SELECT 1 
        FROM [Engagement].[Reviews] r
        INNER JOIN inserted i ON r.UserId = i.UserId AND r.AnimeId = i.AnimeId
    )
    BEGIN
        RAISERROR ('A user can only submit one review per anime.', 16, 1);
        RETURN;
    END

    INSERT INTO [Engagement].[Reviews] (UserId, AnimeId, Score, Comment, ReviewDate)
    SELECT UserId, AnimeId, Score, Comment, ISNULL(ReviewDate, GETDATE())
    FROM inserted;
END;
GO

CREATE TRIGGER [Accounts].[TR_SoftDeleteUsers]
ON [Accounts].[Users]
INSTEAD OF DELETE
AS
BEGIN
    UPDATE [Accounts].[Users]
    SET IsDeleted = 1, DeletedOn = GETDATE()
    WHERE UserId IN (SELECT UserId FROM deleted);
END;
GO

CREATE TRIGGER [Content].[TR_SoftDeleteAnimes]
ON [Content].[Animes]
INSTEAD OF DELETE
AS
BEGIN
    UPDATE [Content].[Animes]
    SET IsDeleted = 1, DeletedOn = GETDATE()
    WHERE AnimeId IN (SELECT AnimeId FROM deleted);
END;
GO

-- ---------------------------------------------------------------------------------------
-- 5. SAMPLE DATA SEEDING
-- ---------------------------------------------------------------------------------------

-- Insert Subscriptions
SET IDENTITY_INSERT [Accounts].[Subscriptions] ON;
INSERT [Accounts].[Subscriptions] ([TierId], [TierName], [MonthlyPrice], [IsAdFree]) VALUES 
(1, N'Free Tier', CAST(0.00 AS Decimal(5, 2)), 0),
(2, N'Fan Monthly', CAST(7.99 AS Decimal(5, 2)), 1),
(3, N'Mega Fan Monthly', CAST(9.99 AS Decimal(5, 2)), 1),
(4, N'Ultimate Fan', CAST(14.99 AS Decimal(5, 2)), 1),
(5, N'Fan Annual', CAST(79.99 AS Decimal(5, 2)), 1),
(6, N'Mega Fan Annual', CAST(99.99 AS Decimal(5, 2)), 1),
(7, N'Student Basic', CAST(4.99 AS Decimal(5, 2)), 1),
(8, N'Student Premium', CAST(6.99 AS Decimal(5, 2)), 1),
(9, N'Family Plan', CAST(19.99 AS Decimal(5, 2)), 1),
(10, N'Mobile Only', CAST(3.99 AS Decimal(5, 2)), 1),
(11, N'Promo 1-Month', CAST(0.00 AS Decimal(5, 2)), 1),
(12, N'Promo 3-Month', CAST(0.00 AS Decimal(5, 2)), 1),
(13, N'Legacy Fan', CAST(5.99 AS Decimal(5, 2)), 1),
(14, N'Legacy Mega', CAST(7.99 AS Decimal(5, 2)), 1),
(15, N'VIP Access', CAST(24.99 AS Decimal(5, 2)), 1),
(16, N'Early Bird', CAST(4.99 AS Decimal(5, 2)), 1),
(17, N'Holiday Special', CAST(5.99 AS Decimal(5, 2)), 1),
(18, N'Weekend Pass', CAST(1.99 AS Decimal(5, 2)), 1),
(19, N'Anime Expo Pass', CAST(0.00 AS Decimal(5, 2)), 1),
(20, N'Lifetime Member', CAST(299.99 AS Decimal(5, 2)), 1);
SET IDENTITY_INSERT [Accounts].[Subscriptions] OFF;
GO

-- Insert Users
SET IDENTITY_INSERT [Accounts].[Users] ON;
INSERT [Accounts].[Users] ([UserId], [TierId], [Username], [Email], [PasswordHash], [DateOfBirth], [IsDeleted], [DeletedOn]) VALUES 
(1, 1, N'NarutoFan99', N'naruto.uzumaki99@gmail.com', N'5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', CAST(N'2001-10-10' AS Date), 0, NULL),
(2, 3, N'GojoSatoru', N'limitless.sixeyes@yahoo.com', N'8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92', CAST(N'1989-12-07' AS Date), 0, NULL),
(3, 2, N'AnimeKing', N'kingofanime_95@hotmail.com', N'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', CAST(N'1995-03-15' AS Date), 0, NULL),
(4, 1, N'Sakura', N'cherryblossom.04@outlook.com', N'03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', CAST(N'2004-06-22' AS Date), 0, NULL),
(5, 3, N'LeviAckerman', N'captain.levi.scouts@gmail.com', N'ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f', CAST(N'1992-12-25' AS Date), 0, NULL),
(6, 2, N'DekuHero', N'oneforall.smash@hero.edu', N'961b6dd3ede3cb8ecbaacbd68de040cd78eb2ed5889130cceb4c49268ea4d506', CAST(N'2005-07-15' AS Date), 0, NULL),
(7, 1, N'SpeedWatcher', N'speedbinge98@protonmail.com', N'c4ca4238a0b923820dcc509a6f75849b14f6082297825b7410292c10db4ce736', CAST(N'1998-11-11' AS Date), 0, NULL),
(8, 4, N'OtakuLife', N'otaku4ever_00@yahoo.com', N'c81e728d9d4c2f636f067f89cc14862c14f6082297825b7410292c10db4ce736', CAST(N'2000-01-01' AS Date), 0, NULL),
(9, 5, N'MechaPilot', N'getintherobot@nerve.net', N'eccbc87e4b5ce2fe28308fd9f2a7baf314f6082297825b7410292c10db4ce736', CAST(N'1996-08-08' AS Date), 0, NULL),
(10, 6, N'IsekaiTrash', N'truckkun.survivor@gmail.com', N'a87ff679a2f3e71d9181a67b7542122c14f6082297825b7410292c10db4ce736', CAST(N'2002-02-20' AS Date), 0, NULL),
(11, 7, N'ShonenJump', N'jump.reader90@outlook.com', N'e4da3b7fbbce2345d7772b0674a318d514f6082297825b7410292c10db4ce736', CAST(N'1990-05-05' AS Date), 0, NULL),
(12, 8, N'ShojoQueen', N'romance.anime.queen@gmail.com', N'1679091c5a880faf6fb5e6087eb1b2dc14f6082297825b7410292c10db4ce736', CAST(N'1999-09-09' AS Date), 0, NULL),
(13, 9, N'HokageInTraining', N'shadowclone.pro@hiddenleaf.org', N'8f14e45fceea167a5a36dedd4bea254314f6082297825b7410292c10db4ce736', CAST(N'2003-03-03' AS Date), 0, NULL),
(14, 10, N'PirateKing', N'grandline.captain@strawhat.com', N'c9f0f895fb98ab9159f51fd0297e236d14f6082297825b7410292c10db4ce736', CAST(N'1997-07-07' AS Date), 0, NULL),
(15, 11, N'Shinobi', N'silent.assassin94@yahoo.com', N'45c48cce2e2d7fbdea1afc51c7c6ad2614f6082297825b7410292c10db4ce736', CAST(N'1994-04-04' AS Date), 0, NULL),
(16, 12, N'GundamBuilder', N'gunpla.master85@hotmail.com', N'd3d9446802a44259755d38e6d163e82014f6082297825b7410292c10db4ce736', CAST(N'1985-05-15' AS Date), 0, NULL),
(17, 13, N'CosplayPro', N'foam.armor.crafter@gmail.com', N'6512bd43d9caa6e02c990b0a82652dca14f6082297825b7410292c10db4ce736', CAST(N'1993-03-23' AS Date), 0, NULL),
(18, 14, N'MangaReader', N'blackandwhite.pages@protonmail.com', N'c20ad4d76fe97759aa27a0c99bff671014f6082297825b7410292c10db4ce736', CAST(N'2001-11-11' AS Date), 0, NULL),
(19, 15, N'WeebCentral', N'anime.takes.over@gmail.com', N'c51ce410c124a10e0db5e4b97fc2af3914f6082297825b7410292c10db4ce736', CAST(N'1998-08-18' AS Date), 0, NULL),
(20, 16, N'TokyoGhoul', N'one.eyed.king@aogiri.com', N'aab3238922bcc25a6f606eb525ffdc5614f6082297825b7410292c10db4ce736', CAST(N'2000-10-31' AS Date), 0, NULL);
SET IDENTITY_INSERT [Accounts].[Users] OFF;
GO

-- Insert User Devices
SET IDENTITY_INSERT [Accounts].[UserDevices] ON;
INSERT INTO [Accounts].[UserDevices] ([DeviceId], [UserId], [DeviceName]) VALUES
(1, 1, N'Smart TV'),
(2, 1, N'iPhone 15'),
(3, 2, N'PlayStation 5'),
(4, 3, N'Web Browser'),
(5, 4, N'Android Phone'),
(6, 5, N'Smart TV'),
(7, 6, N'iPad Pro'),
(8, 7, N'Web Browser'),
(9, 8, N'Xbox Series X'),
(10, 9, N'Smart TV'),
(11, 10, N'Android Phone'),
(12, 11, N'Web Browser'),
(13, 12, N'iPhone 14'),
(14, 13, N'PlayStation 5'),
(15, 14, N'Smart TV'),
(16, 15, N'Web Browser'),
(17, 16, N'Smart TV'),
(18, 17, N'Android Tablet'),
(19, 18, N'Web Browser'),
(20, 19, N'PlayStation 5'),
(21, 20, N'iPhone 15');
SET IDENTITY_INSERT [Accounts].[UserDevices] OFF;
GO

-- Insert Genres
SET IDENTITY_INSERT [Content].[Genres] ON;
INSERT [Content].[Genres] ([GenreId], [Name], [Description]) VALUES 
(1, N'Action', N'High-energy scenes, physical feats, and intense combat.'),
(2, N'Adventure', N'Journeys, explorations, and epic quests across worlds.'),
(3, N'Comedy', N'Lighthearted storylines designed to amuse and provoke laughter.'),
(4, N'Drama', N'Emotionally driven narratives focusing on character development and conflict.'),
(5, N'Fantasy', N'Stories featuring magic, mythical creatures, and imaginary worlds.'),
(6, N'Sci-Fi', N'Futuristic concepts, advanced technology, space exploration, and time travel.'),
(7, N'Romance', N'Plots centering on romantic relationships and love stories.'),
(8, N'Slice of Life', N'Realistic depictions of everyday life and mundane situations.'),
(9, N'Mystery', N'Suspenseful plots focused on solving crimes or uncovering secrets.'),
(10, N'Horror', N'Dark themes intended to scare, disgust, or startle the audience.'),
(11, N'Thriller', N'Tense, suspenseful narratives that keep viewers on the edge of their seats.'),
(12, N'Psychological', N'Explorations of the human mind, mental instability, and complex character psyches.'),
(13, N'Mecha', N'Battles and storylines revolving around giant pilotable robots or machines.'),
(14, N'Sports', N'Competitive physical activities, teamwork, and athletic tournaments.'),
(15, N'Isekai', N'Protagonists being transported to, reborn, or trapped in a parallel universe.'),
(16, N'Music', N'Stories centered around singing, playing instruments, or the music industry.'),
(17, N'Historical', N'Settings and events based on real-world history and past eras.'),
(18, N'Supernatural', N'Elements that defy the laws of nature, including ghosts and spirits.'),
(19, N'Magic', N'Systems of spells, wizards, and supernatural powers as a core theme.'),
(20, N'Martial Arts', N'Focus on hand-to-hand combat, dojos, and traditional fighting styles.');
SET IDENTITY_INSERT [Content].[Genres] OFF;
GO

-- Insert Animes
SET IDENTITY_INSERT [Content].[Animes] ON;
INSERT [Content].[Animes] ([AnimeId], [Title], [Synopsis], [Studio], [ReleaseYear], [IsDeleted], [DeletedOn]) VALUES 
(1, N'Jujutsu Kaisen', N'A boy swallows a cursed talisman to save his friends and enters a shaman school.', N'MAPPA', 2020, 0, NULL),
(2, N'Demon Slayer', N'A young man becomes a demon slayer after his family is slaughtered and his sister turned into a demon.', N'Ufotable', 2019, 0, NULL),
(3, N'One Piece', N'A rubber-powered pirate sets out to find the ultimate treasure and become the Pirate King.', N'Toei', 1999, 0, NULL),
(4, N'Spy x Family', N'A spy, an assassin, and a telepathic child form a fake family to execute a world-saving mission.', N'Wit Studio', 2022, 0, NULL),
(5, N'Attack on Titan', N'Humanity retreats behind massive walls to survive against giant man-eating Titans.', N'MAPPA', 2013, 0, NULL),
(6, N'My Hero Academia', N'A quirkless boy inherits the powers of the world''s greatest hero to attend a superhero high school.', N'Bones', 2016, 0, NULL),
(7, N'Frieren', N'An elf mage goes on a journey to understand humanity after her heroic party passes away.', N'Madhouse', 2023, 0, NULL),
(8, N'Naruto', N'An outcast ninja fights to earn the respect of his village and become the Hokage.', N'Studio Pierrot', 2002, 0, NULL),
(9, N'Bleach', N'A teenager obtains the powers of a Soul Reaper to protect humanity from evil spirits.', N'Studio Pierrot', 2004, 0, NULL),
(10, N'Death Note', N'A high school genius discovers a notebook that kills anyone whose name is written in it.', N'Madhouse', 2006, 0, NULL),
(11, N'Steins;Gate', N'A self-proclaimed mad scientist accidentally invents a time machine out of a microwave.', N'White Fox', 2011, 0, NULL),
(12, N'Hunter x Hunter', N'A young boy sets out to become a Hunter and track down his absentee father.', N'Madhouse', 2011, 0, NULL),
(13, N'Fullmetal Alchemist', N'Two brothers search for the Philosopher''s Stone to restore their bodies after a failed alchemy ritual.', N'Bones', 2009, 0, NULL),
(14, N'Cowboy Bebop', N'A ragtag crew of bounty hunters travel the galaxy in their spaceship, the Bebop.', N'Sunrise', 1998, 0, NULL),
(15, N'Evangelion', N'Teenagers are recruited to pilot giant bio-machines to fight mysterious alien beings called Angels.', N'Gainax', 1995, 0, NULL),
(16, N'Haikyuu!!', N'A short but determined high school student strives to become a volleyball champion.', N'Production I.G', 2014, 0, NULL),
(17, N'Tokyo Ghoul', N'A college student turns into a half-ghoul and must survive in a society divided between humans and flesh-eaters.', N'Studio Pierrot', 2014, 0, NULL),
(18, N'Code Geass', N'An exiled prince obtains a power of absolute obedience and starts a rebellion against a holy empire.', N'Sunrise', 2006, 0, NULL),
(19, N'JoJos Bizarre Adventure', N'The generational saga of the Joestar family using unique powers to fight supernatural foes.', N'David Production', 2012, 0, NULL),
(20, N'Chainsaw Man', N'A teenager merges with a chainsaw devil and is recruited to hunt other devils for the government.', N'MAPPA', 2022, 0, NULL);
SET IDENTITY_INSERT [Content].[Animes] OFF;
GO

-- Insert AnimeGenres
INSERT [Content].[AnimeGenres] ([AnimeId], [GenreId]) VALUES 
(1, 1), (2, 1), (3, 2), (4, 3), (5, 1), 
(6, 1), (7, 5), (8, 1), (9, 1), (10, 9), 
(11, 6), (12, 2), (13, 5), (14, 6), (15, 13), 
(16, 14), (17, 10), (18, 13), (19, 1), (20, 10);
GO

-- Insert Episodes
SET IDENTITY_INSERT [Content].[Episodes] ON;
INSERT [Content].[Episodes] ([EpisodeId], [AnimeId], [EpisodeNumber], [Title], [DurationMinutes]) VALUES 
(1, 1, 24, N'Accomplices', 24),
(2, 2, 19, N'Hinokami', 24),
(3, 3, 1071, N'Luffy''s Peak! Gear 5', 24),
(4, 4, 1, N'Operation Strix', 24),
(5, 5, 54, N'Hero', 24),
(6, 6, 1, N'Izuku Midoriya: Origin', 24),
(7, 7, 1, N'Journey''s End', 25),
(8, 8, 133, N'A Plea from a Friend', 23),
(9, 9, 1, N'The Day I Became a Shinigami', 23),
(10, 10, 25, N'Silence', 22),
(11, 11, 1, N'Turning Point', 24),
(12, 12, 131, N'Anger x and x Light', 23),
(13, 13, 64, N'Journey''s End', 24),
(14, 14, 1, N'Asteroid Blues', 25),
(15, 15, 26, N'Take care of yourself.', 24),
(16, 16, 1, N'Endings and Beginnings', 24),
(17, 17, 12, N'Ghoul', 24),
(18, 18, 50, N'Re;', 24),
(19, 19, 1, N'Dio the Invader', 24),
(20, 20, 1, N'Dog & Chainsaw', 24);
SET IDENTITY_INSERT [Content].[Episodes] OFF;
GO

-- Insert Reviews
SET IDENTITY_INSERT [Engagement].[Reviews] ON;
INSERT [Engagement].[Reviews] ([ReviewId], [UserId], [AnimeId], [Score], [Comment], [ReviewDate]) VALUES 
(1, 1, 1, 5, N'Absolute masterpiece, the animation is unbelievable!', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(2, 2, 7, 5, N'Such a beautiful and relaxing journey.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(3, 3, 2, 4, N'Great action, but pacing is a bit slow sometimes.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(4, 4, 4, 5, N'Anya is the best! So wholesome.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(5, 5, 5, 5, N'Peak fiction. The plot twists are insane.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(6, 6, 6, 4, N'Solid shonen, definitely worth a watch.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(7, 7, 3, 5, N'The world building is unmatched.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(8, 8, 8, 4, N'A classic, though there is too much filler.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(9, 9, 14, 5, N'Best soundtrack in anime history.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(10, 10, 15, 5, N'A psychological masterpiece. Still thinking about the ending.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(11, 11, 9, 3, N'Started off great but lost me in the middle arcs.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(12, 12, 16, 4, N'Surprisingly hype for a sports anime!', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(13, 13, 10, 5, N'The ultimate battle of wits. First half is a 10/10.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(14, 14, 11, 5, N'El Psy Kongroo. Takes a few episodes to get going but it is brilliant.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(15, 15, 12, 4, N'The power system is incredibly well thought out.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(16, 16, 13, 5, N'The perfect anime from start to finish.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(17, 17, 17, 3, N'Read the manga instead. The anime adaptation missed the mark.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(18, 18, 18, 5, N'Lelouch is the greatest protagonist ever written.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(19, 19, 19, 4, N'Bizarre, funny, and incredibly stylish.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2)),
(20, 20, 20, 5, N'Pure chaos in the best way possible.', CAST(N'2026-09-12T11:20:21.8433333' AS DateTime2));
SET IDENTITY_INSERT [Engagement].[Reviews] OFF;
GO

-- Insert WatchHistory
SET IDENTITY_INSERT [Engagement].[WatchHistory] ON;
INSERT [Engagement].[WatchHistory] ([HistoryId], [UserId], [EpisodeId], [WatchDate], [StoppedAtMinute], [IsCompleted]) VALUES 
(1, 1, 1, CAST(N'2026-08-01T14:00:00.0000000' AS DateTime2), 24, 1),
(2, 2, 7, CAST(N'2026-08-05T20:00:00.0000000' AS DateTime2), 25, 1),
(3, 3, 2, CAST(N'2026-08-10T18:00:00.0000000' AS DateTime2), 24, 1),
(4, 4, 4, CAST(N'2026-08-15T16:00:00.0000000' AS DateTime2), 5, 0),
(5, 5, 5, CAST(N'2026-08-20T22:00:00.0000000' AS DateTime2), 24, 1),
(6, 6, 6, CAST(N'2026-08-25T15:00:00.0000000' AS DateTime2), 24, 1),
(7, 7, 3, CAST(N'2026-09-01T09:00:00.0000000' AS DateTime2), 12, 0),
(8, 8, 8, CAST(N'2026-09-02T10:00:00.0000000' AS DateTime2), 23, 1),
(9, 9, 14, CAST(N'2026-09-03T11:00:00.0000000' AS DateTime2), 25, 1),
(10, 10, 15, CAST(N'2026-09-04T12:00:00.0000000' AS DateTime2), 24, 1),
(11, 11, 9, CAST(N'2026-09-05T13:00:00.0000000' AS DateTime2), 10, 0),
(12, 12, 16, CAST(N'2026-09-06T14:00:00.0000000' AS DateTime2), 24, 1),
(13, 13, 10, CAST(N'2026-09-07T15:00:00.0000000' AS DateTime2), 22, 1),
(14, 14, 11, CAST(N'2026-09-08T16:00:00.0000000' AS DateTime2), 24, 1),
(15, 15, 12, CAST(N'2026-09-09T17:00:00.0000000' AS DateTime2), 23, 1),
(16, 16, 13, CAST(N'2026-09-10T18:00:00.0000000' AS DateTime2), 24, 1),
(17, 17, 17, CAST(N'2026-09-11T19:00:00.0000000' AS DateTime2), 15, 0),
(18, 18, 18, CAST(N'2026-09-12T20:00:00.0000000' AS DateTime2), 24, 1),
(19, 19, 19, CAST(N'2026-09-13T21:00:00.0000000' AS DateTime2), 24, 1),
(20, 20, 20, CAST(N'2026-09-14T22:00:00.0000000' AS DateTime2), 20, 0);
SET IDENTITY_INSERT [Engagement].[WatchHistory] OFF;
GO

-- Insert Watchlists
SET IDENTITY_INSERT [Engagement].[Watchlists] ON;
INSERT [Engagement].[Watchlists] ([WatchlistId], [UserId], [AnimeId], [DateAdded]) VALUES 
(2, 1, 5, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(3, 1, 6, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(4, 2, 1, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(5, 2, 4, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(6, 3, 7, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(7, 4, 2, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(8, 5, 8, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(9, 6, 9, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(10, 7, 10, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(11, 8, 11, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(12, 9, 12, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2)),
(13, 10, 15, CAST(N'2026-09-12T11:27:02.3700000' AS DateTime2));
SET IDENTITY_INSERT [Engagement].[Watchlists] OFF;
GO