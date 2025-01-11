declare @username varchar(100) = '$(entra_username)'

if not exists
(
    select *
    from sys.database_principals
    where type in ('E', 'X')
    and name = @username
)
begin
    print 'User ' + @username + ' not found, adding...'

    declare @create_user nvarchar(500) = 'create user [' + @username + '] from external provider'
    execute sp_executesql @sql = @create_user
end
else
begin
    print 'User ' + @username + ' already exists...'
end

select
    name,
    type_desc,
    create_date
from sys.database_principals
where type in ('E', 'X')
and name = @username
