-- user DB script

declare @username nvarchar(500) = '$(entra_username)'

declare @sql1 nvarchar(500) = 'alter role db_datareader add member [' + @username + '];'
declare @sql2 nvarchar(500) = 'alter role db_datawriter add member [' + @username + '];'
declare @sql3 nvarchar(500) = 'alter role db_ddladmin add member [' + @username + '];'
declare @sql4 nvarchar(500) = 'grant execute on database::[' + db_name() + '] to [' + @username + '];'

execute sp_executesql @sql = @sql1
execute sp_executesql @sql = @sql2
execute sp_executesql @sql = @sql3
execute sp_executesql @sql = @sql4


select
    dp.name as [user],
    rp.name as [role]
from sys.database_principals dp
left join sys.database_role_members drm on dp.principal_id = drm.member_principal_id
left join sys.database_principals rp on drm.role_principal_id = rp.principal_id
where dp.name = @username;

select
    pr.state_desc as [permission state],
    pr.permission_name as [permission],
    pr.class_desc as [securable type],
    dp.name as [user]
from sys.database_principals as dp
join sys.database_permissions as pr on pr.grantee_principal_id = dp.principal_id
where pr.permission_name = 'EXECUTE'
and dp.name = @username;
