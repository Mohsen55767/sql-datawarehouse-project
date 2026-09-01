/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/


create or alter procedure silver.load_silver as
begin try
declare @start_date date ,@end_time date,
@batch_start_date date,@batch_end_date date

set @batch_start_date=getdate()
print '>>truncate data before inserting in silver.crm_cust_info'
set @start_date=getdate()
truncate table silver.crm_cust_info
print '>> insert date into : silver.crm_cust_info'
insert into silver.crm_cust_info(
cst_id,
cst_key,
cst_firstname,
cst_lastname,
cst_material_status,
csr_gndr,
cst_create_date
)

select 
cst_id,cst_key,
trim(cst_firstname) as cst_firstname,
trim(cst_lastname )as cst_lastname,

case when  upper(trim(cst_material_status)) ='S' then 'Single'
       when upper(trim(csr_gndr))='M'   then 'Married'
       else 'Unknown'
       end cst_material_status

, case when  upper(trim(csr_gndr)) ='F' then 'Female'
       when upper(trim(csr_gndr))='M'   then 'Male'
       else 'Unknown'
    end csr_gndr,
cst_create_date
from
(
select * 
,ROW_NUMBER() 
over(partition by cst_id order by cst_create_date desc)
as flag_last
from bronze.crm_cust_info as ci
where cst_id is not null
)t
where flag_last=1  

set @end_time=getdate();
print '>> load duration : '+cast(datediff(second,@start_date,@end_time) as nvarchar) +'seconds'; 




------------------------------prd_info
print '>>truncate data before inserting in silver.crm_prd_info'
set @start_date=getdate()
truncate table silver.crm_prd_info
print '>> insert date into : silver.crm_prd_info'
insert into silver.crm_prd_info(
prd_id,
cat_id,
prd_key,
prd_nm,
prd_cost,
prd_line,
prd_start_dt,
prd_end_dt
)
select
prd_id,
replace(substring(pi.prd_key,1,5),'-','_')as cat_id,
SUBSTRING(pi.prd_key,7,len(pi.prd_key))as prd_key,
prd_nm,
isnull(pi.prd_cost,0) as prd_cost,
case when upper(trim(prd_line))='M' then 'Mountain'
     when upper(trim(prd_line))='R' then 'Roud'
     when upper(trim(prd_line))='S' then 'Other sales'
     when upper(trim(prd_line))='T' then 'Touring'
     else 'Unknown'
end as prd_line,
cast(pi.prd_start_dt as date)as prd_start_dt,
cast(lead(prd_start_dt) over(partition by prd_key order by prd_start_dt)-1 as date)as prd_end_dt
from bronze.crm_prd_info as pi

set @end_time=getdate()
print '>> load duration '+ cast(datediff(second,@start_date,@end_time) as varchar)+'seconds'

----------------------------
--------silver.sales_details
print '>>truncate data before inserting in silver.crm_sales_details'
set @start_date=getdate()
truncate table silver.crm_sales_details
print '>> insert date into : silver.crm_sales_details'
insert into silver.crm_sales_details(
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price

)
select sd.sls_ord_num,sd.sls_prd_key,sd.sls_cust_id,

case when sls_order_dt=0 or len(sls_order_dt) !=8 then null
    else cast(cast(sls_order_dt as varchar) as date)
    end as sls_order_dt
    ,
case when sls_ship_dt =0 or len(sls_ship_dt) !=8 then null
    else cast(cast(sls_ship_dt as varchar) as date)
    end as sls_ship_dt
,
case when sd.sls_due_dt =0 or len(sd.sls_due_dt) !=8 then null
    else cast(cast(sd.sls_due_dt as varchar) as date)
    end as sls_due_dt
,
case when sd.sls_sales is null or  sd.sls_sales<=0 
     or  sd.sls_sales!= sd.sls_quantity * abs(sd.sls_price) 
     then sd.sls_quantity*abs(sd.sls_price)
     else  sd.sls_sales
end as  sls_sales ,
sd.sls_quantity,
case when sd.sls_price is null or sd.sls_price <=0
     then sls_sales/sls_quantity
     else sls_price
end as sls_price
from bronze.crm_sales_details as sd

set @end_time=getdate();
print '>> load duration : '+cast(datediff(second,@start_date,@end_time) as nvarchar) +'seconds'; 
--------------------
-------silver.erp_cust_az12
print '>>truncate data before inserting in  silver.erp_cust_az12'
set @start_date=getdate()
truncate table  silver.erp_cust_az12
print '>> insert date into :  silver.erp_cust_az12'
insert into silver.erp_cust_az12(cid,bdate,gen)
select 
case when cid like 'NAS%' then substring(ec.cid,4,len(cid))
     else cid
 end cid 
,
case when bdate >getdate() then null
      else bdate
end as bdate 
,
case when upper(trim(gen))='F' then 'Female'
     when upper(trim(gen))='M' then 'Male'
     when upper(trim(gen))='' then 'Unknown'
     when  upper(trim(gen))is null then 'Unknown'
     else gen 
end as gen 

from bronze.erp_cust_az12 as ec

set @end_time=getdate();
print '>> load duration : '+cast(datediff(second,@start_date,@end_time) as nvarchar) +'seconds'; 
--------------------------------------




-----------silver.erp_loc_a101
set @start_date=GETDATE()
print '>>truncate data before inserting in  silver.erp_loc_a101'
truncate table silver.erp_loc_a101
print '>> insert date into :  silver.erp_loc_a101'
insert into silver.erp_loc_a101
(
cid,
cntry
)
select replace(cid,'-','') cid,
case when cntry is null then 'Unknown'
      when cntry='' then 'Unknown'
      when trim(cntry) ='DE' then 'Germany'
      when trim(cntry) in ('USA','US') then 'United States'
           else cntry
      end cntry
from bronze.erp_loc_a101

set @end_time=getdate();
print '>> load duration : '+cast(datediff(second,@start_date,@end_time) as nvarchar) +'seconds'; 
-------------------------------------------

----------silver.erp_px_cat_g1v2
     print '>>truncate data before inserting in  silver.erp_px_cat_g1v2'
     set @start_date=getdate()
truncate table silver.erp_px_cat_g1v2
print '>> insert date into :  silver.erp_px_cat_g1v2'

insert into silver.erp_px_cat_g1v2
(
id,
cat,
subcat,
maintenance
)
select id ,cat,subcat,maintenance
from bronze.erp_px_cat_g1v2


set @batch_end_date=getdate();
print '>> total load duration : '+cast(datediff(second,@batch_start_date,@batch_end_date) as nvarchar) +'seconds'
print'-----------------------------------'
end try

begin catch 
print'=========================='
print 'error occured during loading bronze layer '
print 'error message'+error_message();
print 'error message'+cast (error_number() as nvarchar);
print 'error message' + cast(error_state() as nvarchar)
end catch;

exec silver.load_silver
