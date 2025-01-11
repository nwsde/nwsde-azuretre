set nocount on;

declare @username varchar(1000) = '$(username)'

select
    [sid]
from sys.database_principals
where [name] = @username
