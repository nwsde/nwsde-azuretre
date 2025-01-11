declare @admin_username varchar(100) = '$(admin_username)'

--
-- nwsde_datareader
--
if not exists (select * from sys.database_principals where name = 'nwsde_datareader' and type = 'R')
begin
    declare @sql1 nvarchar(1000) = 'create role nwsde_datareader authorization [' + @admin_username + ']';
    execute sp_executesql @sql1
end

grant select to nwsde_datareader;

--
-- nwsde_datawriter
--
if not exists (select * from sys.database_principals where name = 'nwsde_datawriter' and type = 'R')
begin
    declare @sql2 nvarchar(1000) = 'create role nwsde_datawriter authorization [' + @admin_username + ']';
    execute sp_executesql @sql2
end

grant insert to nwsde_datawriter;
grant update to nwsde_datawriter;
grant delete to nwsde_datawriter;

--
-- nwsde_executor
--
if not exists (select * from sys.database_principals where name = 'nwsde_dataexecutor' and type = 'R')
begin
    declare @sql3 nvarchar(1000) = 'create role nwsde_dataexecutor authorization [' + @admin_username + ']';
    execute sp_executesql @sql3
end

grant execute to nwsde_dataexecutor;

--
-- nwsde_ddladmin
--
if not exists (select * from sys.database_principals where name = 'nwsde_ddladmin' and type = 'R')
begin
    declare @sql4 nvarchar(1000) = 'create role nwsde_ddladmin authorization [' + @admin_username + ']';
    execute sp_executesql @sql4
end

grant create schema to nwsde_ddladmin;
grant create table to nwsde_ddladmin;
grant create view to nwsde_ddladmin;
grant create procedure to nwsde_ddladmin;
grant create function to nwsde_ddladmin;
grant references to nwsde_ddladmin;

select
    name,
    principal_id,
    type,
    type_desc,
    create_date
from sys.database_principals
where is_fixed_role = 0
and type = 'R'
and owning_principal_id = database_principal_id(@admin_username)

