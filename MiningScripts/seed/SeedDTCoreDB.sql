IF EXISTS (
    SELECT
        SiteId
    FROM
        [dbo].[DT_SiteSettings]
    WHERE
        SiteId = CAST($(SiteId) AS UNIQUEIDENTIFIER)
)
BEGIN
    PRINT 'ADT Instance URI for Site ID "' + $(SiteId) + '" already exists in table DT_SiteSettings.'
END
ELSE
BEGIN
    INSERT INTO
        [dbo].[DT_SiteSettings] (
            [SiteId],
            [InstanceUri],
            [SiteCodeForModelId]
        )
    VALUES
        (
            CAST($(SiteId) AS UNIQUEIDENTIFIER),
            $(ADTInstanceUri),
            UPPER($(SiteName))
        )
    PRINT 'ADT Instance URI for Site ID"' + $(SiteId) + '" was inserted into table DT_SiteSettings.'
END