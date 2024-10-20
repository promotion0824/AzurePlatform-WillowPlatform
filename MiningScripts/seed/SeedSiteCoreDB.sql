IF EXISTS (
    SELECT
        Id
    FROM
        [dbo].[Sites]
    WHERE
        Id = CAST($(SiteId) AS UNIQUEIDENTIFIER)
)
BEGIN
    PRINT 'Site "' + $(SiteName) + '" already exists in table Sites.'
END
ELSE
BEGIN
    INSERT INTO
        [dbo].[Sites] (
            [Id],
            [CustomerId],
            [PortfolioId],
            [Name],
            [Code],
            [Address],
            [State],
            [Postcode],
            [Country],
            [NumberOfFloors],
            [Area],
            [LogoId],
            [Latitude],
            [Longitude],
            [TimezoneId],
            [Status],
            [Suburb],
            [Type]
        )
    VALUES
        (
            CAST($(SiteId) AS UNIQUEIDENTIFIER),
            CAST($(CustomerId) AS UNIQUEIDENTIFIER),
            CAST($(PortfolioId) AS UNIQUEIDENTIFIER),
            $(SiteName),
            UPPER($(SiteName)),
            '',--SiteAddress
            '',--SiteState
            '',--SitePostcode
            '',--SiteCountry
            0,
            10000,
            null,
            0,--SiteLatitude
            0,--SiteLongitude
            $(SiteTimeZone),
            1,
            '',--SiteSuburb
            3
        )
    PRINT 'Site "' + $(SiteName) + '" was inserted into table Sites.'
END