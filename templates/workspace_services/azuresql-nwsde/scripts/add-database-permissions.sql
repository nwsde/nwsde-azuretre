declare @username nvarchar(500) = '$(username)'

declare @sql1 nvarchar(500) = 'alter role nwsde_datareader add member [' + @username + '];'
execute sp_executesql @sql = @sql1

declare @sql2 nvarchar(500) = 'alter role nwsde_datawriter add member [' + @username + '];'
execute sp_executesql @sql = @sql2

declare @sql3 nvarchar(500) = 'alter role nwsde_dataexecutor add member [' + @username + '];'
execute sp_executesql @sql = @sql3

declare @sql4 nvarchar(500) = 'alter role nwsde_ddladmin add member [' + @username + '];'
execute sp_executesql @sql = @sql4


select
    dp.name as [user],
    rp.name as [role]
from sys.database_principals dp
left join sys.database_role_members drm on dp.principal_id = drm.member_principal_id
left join sys.database_principals rp on drm.role_principal_id = rp.principal_id
where dp.name = @username;

