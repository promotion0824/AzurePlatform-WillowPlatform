DECLARE @SiteId VARCHAR(36),
    @PortfolioId VARCHAR(36),
    @UserId UNIQUEIDENTIFIER,
    @AdminRoleId UNIQUEIDENTIFIER,
    @AdminRoleName VARCHAR(100)

-- Insert Customer Record
IF EXISTS (
    SELECT
        Id
    FROM
        [dbo].[Customers]
    WHERE
        Id = CAST($(CustomerId) AS UNIQUEIDENTIFIER)
)
BEGIN
    PRINT 'Customer with Id "' + $(CustomerId) + '" already exists in table Customers.'
END
ELSE
BEGIN
    INSERT INTO
        [dbo].[Customers] (
            [Id],
            [Name],
            [Address1],
            [Address2],
            [Suburb],
            [Postcode],
            [Country],
            [Status],
            [State],
            [LogoId],
            [FeaturesJson],
            [AccountExternalId]
        )
    VALUES
        (
            CAST($(CustomerId) AS UNIQUEIDENTIFIER),
            $(LongCustomerName),
            '',
            '',
            '',
            '',
            $(CustomerCountry),
            1,
            '',
            NULL,
            '',
            $(CustomerAccountExternalId)
        )
    PRINT 'Customer "' + $(LongCustomerName) + '" was inserted into table Customers.'
END

-- Insert Portfolio record
IF EXISTS (
    SELECT
        Id
    FROM
        [dbo].[Portfolios]
    WHERE
        CustomerId = CAST($(CustomerId) AS UNIQUEIDENTIFIER)
        AND [Name] = $(LongCustomerName)
)
BEGIN
    PRINT 'Portfolio "' + $(LongCustomerName) + '" already exists in table Portfolios.'
    SET @PortfolioId =
        (SELECT
            Id
        FROM
            [dbo].[Portfolios]
        WHERE
            CustomerId = CAST($(CustomerId) AS UNIQUEIDENTIFIER)
            AND [Name] = $(LongCustomerName))
END
ELSE BEGIN
    INSERT INTO
        [dbo].[Portfolios] (
            [Id],
            [Name],
            [CustomerId],
            [FeaturesJson]
        )
    VALUES
        (
            CAST($(PortfolioId) AS UNIQUEIDENTIFIER),
            $(LongCustomerName),
            CAST($(CustomerId) AS UNIQUEIDENTIFIER),
            ''
        )
    PRINT 'Portfolio "' + $(LongCustomerName) + '" was inserted into table Portfolios.'
    SET @PortfolioId = $(PortfolioId)
END

-- Insert Site record
IF EXISTS (
    SELECT
        Id
    FROM
        [dbo].[Sites]
    WHERE
        CustomerId = CAST($(CustomerId) AS UNIQUEIDENTIFIER)
        AND [Name] = $(SiteName)
)
BEGIN
    PRINT 'Site "' + $(SiteName) + '" already exists in table Sites.'
    SET @SiteId =
        (SELECT
            Id
        FROM
            [dbo].[Sites]
        WHERE
            CustomerId = CAST($(CustomerId) AS UNIQUEIDENTIFIER)
            AND [Name] = $(SiteName))
END
ELSE
BEGIN
    INSERT INTO
        [dbo].[Sites] (
            [Id],
            [CustomerId],
            [Name],
            [Code],
            [Status],
            [PortfolioId],
            [FeaturesJson],
            [TimezoneId]
        )
    VALUES
        (
            CAST($(SiteId) AS UNIQUEIDENTIFIER),
            CAST($(CustomerId) AS UNIQUEIDENTIFIER),
            $(SiteName),
            UPPER($(SiteName)),
            0,
            CAST($(PortfolioId) AS UNIQUEIDENTIFIER),
            '{"isTicketingDisabled":false,"isInsightsDisabled":false,"is2DViewerDisabled":false,"isReportsEnabled":true,"useAzureDigitalTwins":true,"is3DAutoOffsetEnabled":false,"isInspectionEnabled":false,"isOccupancyEnabled":false,"isPreventativeMaintenanceEnabled":false,"isCommandsEnabled":false,"isScheduledTicketsEnabled":false}',
            $(SiteTimeZone)
        )
    PRINT 'Site "' + $(SiteName) + '" was inserted into table Sites.'
    SET @SiteId = $(SiteId)
END

-- Insert User Record
IF EXISTS (
    SELECT
        Id
    FROM
        [dbo].[Users]
    WHERE
        (FirstName = 'Admin'
        AND LastName = 'Willow')
        OR Email =  $(SupervisorEmail)
)
BEGIN
    SET @UserId =
        (SELECT
            Id
        FROM
            [dbo].[Users]
        WHERE
            (FirstName = 'Admin'
            AND LastName = 'Willow')
            OR Email =  $(SupervisorEmail))
    PRINT 'User "Admin Willow" already exists in table Users'
END
ELSE
BEGIN
    SET @UserId = NEWID()
    INSERT INTO
    [dbo].[Users]
        ([Id]
        ,[FirstName]
        ,[LastName]
        ,[Email]
        ,[EmailConfirmationToken]
        ,[EmailConfirmationTokenExpiry]
        ,[EmailConfirmed]
        ,[Mobile]
        ,[Status]
        ,[Auth0UserId]
        ,[CreatedDate]
        ,[Initials]
        ,[CustomerId]
        ,[AvatarId]
        ,[Company])
     VALUES
        (
            @UserId,
            'Admin',
            'Willow',
            $(SupervisorEmail),
            '0ca1d695e0e74059afa2a562cb19c4d7',
            GETUTCDATE(),
            1,
            '0411222333',
            1,
            'NOTUSED',
            GETUTCDATE(),
            'AW',
            CAST($(CustomerId) AS UNIQUEIDENTIFIER),
            null,
            'Willow'
        )
    PRINT 'User "Admin Willow" was inserted into table Users'
END

-- Insert Assignments Record
SET @AdminRoleName = 'Customer Admin'
IF EXISTS (
    SELECT
        Id
    FROM
        [dbo].[Roles]
    WHERE
        NAME = @AdminRoleName
)
BEGIN
    SET @AdminRoleId =
        (SELECT
            Id
        FROM
            [dbo].[Roles]
        WHERE
            NAME = @AdminRoleName)

    IF EXISTS (
        SELECT
            PrincipalId
        FROM
            [dbo].[Assignments]
        WHERE
            PrincipalId = @UserId
            AND RoleId = @AdminRoleId
            AND ResourceId = CAST($(CustomerId) AS UNIQUEIDENTIFIER)
    )
    BEGIN
        PRINT '"Admin Willow" is already a ' + @AdminRoleName + '.'
    END
    ELSE
    BEGIN
        INSERT INTO
        [dbo].[Assignments]
            ([PrincipalId]
            ,[PrincipalType]
            ,[RoleId]
            ,[ResourceId]
            ,[ResourceType])
        VALUES
            (
                @UserId,
                1,
                @AdminRoleId,
                CAST($(CustomerId) AS UNIQUEIDENTIFIER), -- ResourceId can be either Sites.Id, Portfoliod.Id or Customers.Id depending on the level of access for user
                1
            )
        PRINT 'Role ' + @AdminRoleName + ' was assigned to user "Admin Willow".'
    END
END
ELSE
BEGIN
    PRINT 'Role "' + @AdminRoleName + '" does not exist in the Roles table.'
END
SELECT @SiteId AS 'SiteId', @PortfolioId as 'PortfolioId'