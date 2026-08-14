USE [master]
GO
/****** Object:  Database [cresql]    Script Date: 1/30/2026 5:30:24 PM ******/
CREATE DATABASE [cresql]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'cresql', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.PCAMERICA\MSSQL\Data\cresql.mdf' , SIZE = 1169472KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'cresql_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.PCAMERICA\MSSQL\Data\cresql_log.ldf' , SIZE = 138496KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
 WITH CATALOG_COLLATION = DATABASE_DEFAULT
GO
ALTER DATABASE [cresql] SET COMPATIBILITY_LEVEL = 110
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [cresql].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [cresql] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [cresql] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [cresql] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [cresql] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [cresql] SET ARITHABORT OFF 
GO
ALTER DATABASE [cresql] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [cresql] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [cresql] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [cresql] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [cresql] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [cresql] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [cresql] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [cresql] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [cresql] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [cresql] SET  DISABLE_BROKER 
GO
ALTER DATABASE [cresql] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [cresql] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [cresql] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [cresql] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [cresql] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [cresql] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [cresql] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [cresql] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [cresql] SET  MULTI_USER 
GO
ALTER DATABASE [cresql] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [cresql] SET DB_CHAINING OFF 
GO
ALTER DATABASE [cresql] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [cresql] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE [cresql] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [cresql] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
ALTER DATABASE [cresql] SET QUERY_STORE = OFF
GO
USE [cresql]
GO
/****** Object:  User [NT AUTHORITY\SYSTEM]    Script Date: 1/30/2026 5:30:24 PM ******/
CREATE USER [NT AUTHORITY\SYSTEM] FOR LOGIN [NT AUTHORITY\SYSTEM] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [NT AUTHORITY\SYSTEM]
GO
ALTER ROLE [db_datareader] ADD MEMBER [NT AUTHORITY\SYSTEM]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [NT AUTHORITY\SYSTEM]
GO
/****** Object:  UserDefinedFunction [dbo].[ConvertToDateKey]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create function [dbo].[ConvertToDateKey] 
(
	@date datetime,
	@datetype varchar(10) -- year '2018', month '2018-02', day '2018-02-03'
)
returns varchar(20)
as
begin
	declare @result varchar(20)
	select @result = convert(varchar(4),DatePart(year, @date))	
	
	if @datetype = 'year' begin
		select @result = convert(varchar(4),DatePart(year, @date))	
	end else if @datetype = 'month' begin
		select @result = convert(varchar(4),DatePart(year, @date)) + '-' 
			+ REPLACE(STR(DATEPART(MONTH, @date),2),' ','0') 
	end else if @datetype = 'day' begin
		select @result = convert(varchar(4),DatePart(year, @date)) + '-' 
			+ REPLACE(STR(DATEPART(MONTH, @date),2),' ','0')  + '-' 
			+ REPLACE(STR(DATEPART(day, @date),2),' ','0') 

	end

	return @result ;
end
GO
/****** Object:  UserDefinedFunction [dbo].[getStartDateOfPayPeriod]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[getStartDateOfPayPeriod]
(
	@incomingDate dateTime,
	@workweekStartDay int
)
RETURNS DateTime
AS
BEGIN
		declare @i int ;
		select @i = DatePart(dw, @incomingDate) 
		
		while @i <> @workweekStartDay
			begin								
				select @incomingDate = DATEADD(d, -1, @incomingDate ) 	
				select @i = DatePart(dw, @incomingDate) 			
			end 	
	
	declare @tempDate date
	select @tempDate = CONVERT(date, @incomingDate)
	select @incomingDate = convert(DateTime,@tempDate)
	
	return @incomingDate
END
GO
/****** Object:  UserDefinedFunction [dbo].[ToJson]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[ToJson] (@XMLResult XML)
RETURNS NVARCHAR(MAX)
WITH EXECUTE AS CALLER
AS
BEGIN

DECLARE  @JSONVersion NVARCHAR(MAX), @Rowcount INT
SELECT @JSONVersion = '', @rowcount=COUNT(*) FROM @XMLResult.nodes('/root/*') x(a)
SELECT @JSONVersion=@JSONVersion+
STUFF(
  (SELECT TheLine FROM 
    (SELECT ',
    {'+
      STUFF((SELECT ',"'+COALESCE(b.c.value('local-name(.)', 'NVARCHAR(255)'),'')+'":"'+
       REPLACE( --escape tab properly within a value
         REPLACE( --escape return properly
           REPLACE( --linefeed must be escaped
             REPLACE( --backslash too
               REPLACE(COALESCE(b.c.value('text()[1]','NVARCHAR(MAX)'),''),--forwardslash
               '\', '\\'),   
              '/', '\/'),   
          CHAR(10),'\n'),   
         CHAR(13),'\r'),   
       CHAR(09),'\t')   
     +'"'   
     FROM x.a.nodes('*') b(c) 
     FOR XML PATH(''),TYPE).value('(./text())[1]','NVARCHAR(MAX)'),1,1,'')+'}'
   FROM @XMLResult.nodes('/root/*') x(a)
   ) JSON(theLine)
  FOR XML PATH(''),TYPE).value('.','NVARCHAR(MAX)' )
,1,1,'')
IF @Rowcount>1 RETURN '['+@JSONVersion+']'
RETURN @JSONVersion
END
GO
/****** Object:  UserDefinedFunction [dbo].[ufn_DelSplChrFromStr]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 CREATE FUNCTION [dbo].[ufn_DelSplChrFromStr](  @INPUT_STRING VARCHAR(MAX))  RETURNS VARCHAR(MAX)    AS BEGIN    if @INPUT_STRING is null       return null    declare @INPUT_STRING2 varchar(256)    set @INPUT_STRING2 = ''    declare @l int    set @l = len(@INPUT_STRING)    declare @p int    set @p = 1    while @p <= @l begin       declare @c int       set @c = ascii(substring(@INPUT_STRING, @p, 1))       if @c between 48 and 57 or @c between 65 and 90 or @c between 97 and 122          set @INPUT_STRING2 = @INPUT_STRING2 + char(@c)       set @p = @p + 1       end    if len(@INPUT_STRING2) = 0       return null       return @INPUT_STRING2  END 
GO
/****** Object:  UserDefinedFunction [dbo].[ufn_InitCap]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[ufn_InitCap]  (    @InputString AS VARCHAR(MAX) ) RETURNS VARCHAR(MAX) AS BEGIN SET @InputString = LOWER(ISNULL(@InputString,'')) DECLARE @Length INT DECLARE @CharIndex INT DECLARE @PChar AS CHAR(1) SELECT @Length = LEN(@InputString), @CharIndex = 1  IF(@Length > 0) BEGIN	WHILE @CharIndex <= @Length	BEGIN      SET @PChar = SUBSTRING(@InputString,@CharIndex-1,1)      IF @PChar IN(' ','.','?',';','!') 	   SET @InputString = STUFF(@InputString,@CharIndex,1,UPPER(SUBSTRING(@InputString,@CharIndex,1)))         	   SET @CharIndex = @CharIndex + 1   END END RETURN @InputString END
GO
/****** Object:  UserDefinedFunction [dbo].[ufn_ReturnInStock]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 CREATE FUNCTION [dbo].[ufn_ReturnInStock](@ItemNum Varchar(max))  RETURNS DECIMAL  WITH EXECUTE AS CALLER  AS  BEGIN  	DECLARE @ReturnInStock DECIMAL;  	SELECT @ReturnInStock =  	CASE   		WHEN j.SumOfItems IS NULL THEN i.In_Stock   		WHEN j.SumOfItems IS NOT NULL THEN i.In_Stock - j.SumOfItems     		ELSE i.In_Stock   	END   	FROM Inventory i   	LEFT JOIN   	(  		SELECT OuterTbl.Code, SUM(OuterTbl.Quantity) AS SumOfItems  FROM   		(  			SELECT p.value('(./Code)[1]', 'varchar(8000)') AS [Code],   			CONVERT(DECIMAL, p.value('(./Quantity)[1]', 'varchar(8000)')) AS [Quantity]  			FROM (SELECT CAST(Data AS XML) AS DATA1,ID FROM [Exchange] where [Status] =0) e     			CROSS APPLY DATA1.nodes('/Order/Item') AS t(p)  		) OuterTbl  		GROUP BY OuterTbl.Code  	 ) j  	ON i.ItemNum = j.Code   	WHERE i.ItemNum = @ItemNum AND    i.Store_ID in (select top 1 Store_ID  from User_Defined where ud_id ='RONLORD' and Description = 'NITROSELLENABLED' and type = 1);  	return @ReturnInStock;  END 
GO
/****** Object:  Table [dbo].[Inventory]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory](
	[ItemNum] [nvarchar](20) NOT NULL,
	[ItemName] [nvarchar](30) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cost] [decimal](25, 8) NOT NULL,
	[Price] [decimal](25, 8) NOT NULL,
	[Retail_Price] [decimal](25, 8) NOT NULL,
	[In_Stock] [decimal](25, 8) NOT NULL,
	[Reorder_Level] [float] NOT NULL,
	[Reorder_Quantity] [float] NOT NULL,
	[Tax_1] [bit] NOT NULL,
	[Tax_2] [bit] NOT NULL,
	[Tax_3] [bit] NOT NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Dept_ID] [nvarchar](8) NOT NULL,
	[IsKit] [bit] NOT NULL,
	[IsModifier] [bit] NOT NULL,
	[Kit_Override] [money] NULL,
	[Inv_Num_Barcode_Labels] [int] NOT NULL,
	[Use_Serial_Numbers] [bit] NOT NULL,
	[Num_Bonus_Points] [int] NOT NULL,
	[IsRental] [bit] NOT NULL,
	[Use_Bulk_Pricing] [bit] NOT NULL,
	[Print_Ticket] [bit] NOT NULL,
	[Print_Voucher] [bit] NOT NULL,
	[Num_Days_Valid] [int] NOT NULL,
	[IsMatrixItem] [bit] NOT NULL,
	[Vendor_Part_Num] [nvarchar](20) NULL,
	[Location] [nvarchar](20) NULL,
	[AutoWeigh] [bit] NOT NULL,
	[numBoxes] [int] NULL,
	[Dirty] [bit] NOT NULL,
	[Tear] [real] NULL,
	[NumPerCase] [int] NULL,
	[FoodStampable] [bit] NOT NULL,
	[ReOrder_Cost] [money] NULL,
	[Helper_ItemNum] [nvarchar](20) NULL,
	[ItemName_Extra] [nvarchar](40) NULL,
	[Exclude_Acct_Limit] [bit] NOT NULL,
	[Check_ID] [bit] NOT NULL,
	[Old_InStock] [decimal](25, 8) NULL,
	[Date_Created] [datetime] NULL,
	[ItemType] [smallint] NULL,
	[Prompt_Price] [bit] NOT NULL,
	[Prompt_Quantity] [bit] NOT NULL,
	[Inactive] [smallint] NULL,
	[Allow_BuyBack] [bit] NOT NULL,
	[Last_Sold] [datetime] NULL,
	[Unit_Type] [nvarchar](10) NULL,
	[Unit_Size] [float] NULL,
	[Fixed_Tax] [money] NULL,
	[DOB] [money] NULL,
	[Special_Permission] [bit] NOT NULL,
	[Prompt_Description] [bit] NOT NULL,
	[Check_ID2] [bit] NOT NULL,
	[Count_This_Item] [bit] NOT NULL,
	[Transfer_Cost_Markup] [real] NULL,
	[Print_On_Receipt] [bit] NOT NULL,
	[Transfer_Markup_Enabled] [bit] NOT NULL,
	[As_Is] [bit] NOT NULL,
	[InStock_Committed] [smallint] NULL,
	[RequireCustomer] [bit] NULL,
	[PromptCompletionDate] [bit] NULL,
	[PromptInvoiceNotes] [bit] NULL,
	[Prompt_DescriptionOverDollarAmt] [money] NULL,
	[Exclude_From_Loyalty] [bit] NULL,
	[BarTaxInclusive] [bit] NULL,
	[ScaleSingleDeduct] [bit] NULL,
	[GLNumber] [nvarchar](20) NULL,
	[ModifierType] [int] NULL,
	[Position] [int] NULL,
	[numberOfFreeToppings] [float] NULL,
	[ScaleItemType] [int] NULL,
	[DiscountType] [int] NULL,
	[AllowReturns] [bit] NULL,
	[SuggestedDeposit] [money] NULL,
	[Liability] [bit] NULL,
	[IsDeleted] [bit] NULL,
	[ItemLocale] [int] NULL,
	[QuantityRequired] [decimal](25, 8) NULL,
	[AllowOnDepositInvoices] [bit] NULL,
	[Import_Markup] [real] NOT NULL,
	[PricePerMeasure] [money] NOT NULL,
	[UnitMeasure] [float] NULL,
	[ShipCompliantProductType] [nvarchar](25) NULL,
	[AlcoholContent] [real] NULL,
	[AvailableOnline] [bit] NOT NULL,
	[AllowOnFleetCard] [bit] NULL,
	[DoughnutTax] [bit] NOT NULL,
	[DisplayTaxInPrice] [bit] NULL,
	[NeverPrintInKitchen] [bit] NULL,
	[RowID] [uniqueidentifier] NOT NULL,
	[Tax_4] [bit] NULL,
	[Tax_5] [bit] NULL,
	[Tax_6] [bit] NULL,
	[DisableInventoryUpload] [bit] NOT NULL,
	[InvoiceLimitQty] [float] NOT NULL,
	[ItemCategory] [int] NOT NULL,
	[IsRestrictedPerInvoice] [bit] NOT NULL,
	[TagStatus] [nvarchar](30) NULL,
 CONSTRAINT [pkInventory] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Categories]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Categories](
	[Cat_ID] [nvarchar](8) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Description] [nvarchar](30) NULL,
 CONSTRAINT [pkCategories] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Cat_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Departments]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Departments](
	[Dept_ID] [nvarchar](8) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Description] [nvarchar](30) NOT NULL,
	[Type] [smallint] NOT NULL,
	[TSDisplay] [bit] NOT NULL,
	[Cost_MarkUp] [real] NOT NULL,
	[Dirty] [bit] NOT NULL,
	[SubType] [nvarchar](8) NOT NULL,
	[Print_Dept_Notes] [bit] NOT NULL,
	[Dept_Notes] [ntext] NULL,
	[Require_Permission] [bit] NOT NULL,
	[Require_Serials] [bit] NOT NULL,
	[BarTaxInclusive] [bit] NULL,
	[Cost_Calculation_Percentage] [real] NULL,
	[Square_Footage] [bigint] NULL,
	[AvailableOnline] [bit] NOT NULL,
	[IncludeInScaleExport] [bit] NULL,
	[RowID] [uniqueidentifier] NOT NULL,
 CONSTRAINT [pkDepartments] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Dept_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Itemized]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Itemized](
	[Invoice_Number] [bigint] NOT NULL,
	[LineNum] [int] NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Quantity] [decimal](25, 8) NOT NULL,
	[CostPer] [decimal](25, 8) NOT NULL,
	[PricePer] [decimal](25, 8) NOT NULL,
	[Tax1Per] [decimal](25, 8) NOT NULL,
	[Tax2Per] [decimal](25, 8) NOT NULL,
	[Tax3Per] [decimal](25, 8) NOT NULL,
	[Serial_Num] [bit] NOT NULL,
	[Kit_ItemNum] [nvarchar](20) NULL,
	[BC_Invoice_Number] [int] NULL,
	[LineDisc] [decimal](25, 8) NULL,
	[DiffItemName] [nvarchar](30) NULL,
	[NumScans] [int] NULL,
	[numBonus] [int] NULL,
	[Line_Tax_Exempt] [bit] NOT NULL,
	[Commission] [decimal](25, 8) NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[origPricePer] [decimal](25, 8) NULL,
	[Allow_Discounts] [bit] NOT NULL,
	[Person] [nvarchar](15) NULL,
	[Sale_Type] [smallint] NULL,
	[Ticket_Number] [nvarchar](15) NULL,
	[IsRental] [bit] NOT NULL,
	[FixedTaxPer] [decimal](25, 8) NULL,
	[GC_Sold] [money] NULL,
	[Special_Price_Lock] [bit] NOT NULL,
	[As_Is] [bit] NOT NULL,
	[Returned] [bit] NOT NULL,
	[DOB] [money] NULL,
	[UserDefined] [nvarchar](20) NULL,
	[Cashier_ID_Itemized] [nvarchar](10) NULL,
	[IsLayaway] [bit] NULL,
	[ReturnedQuantity] [decimal](25, 8) NULL,
	[GC_Free] [money] NULL,
	[ScaleItemType] [int] NULL,
	[ObjectID] [nvarchar](40) NULL,
	[ParentObjectID] [nvarchar](40) NULL,
	[BulkRate] [nvarchar](25) NULL,
	[SecurityDeposit] [money] NULL,
	[Liability] [money] NULL,
	[SalePricePer] [decimal](25, 8) NULL,
	[Line_Tax_Exempt_2] [bit] NULL,
	[Line_Tax_Exempt_3] [bit] NULL,
	[modifierPriceLock] [bit] NOT NULL,
	[Salesperson] [nvarchar](10) NULL,
	[ComboApplied] [bit] NULL,
	[KitchenQuantityPrinted] [decimal](25, 8) NULL,
	[PricePerBeforeDiscount] [decimal](25, 8) NOT NULL,
	[OrigPriceSetBy] [int] NULL,
	[PriceChangedBy] [int] NULL,
	[Kit_Override] [money] NULL,
	[KitTotal] [money] NULL,
	[SentToKitchen] [bit] NULL,
	[OnlineLoyalty_OfferId] [nvarchar](25) NULL,
	[Tax4Per] [decimal](25, 8) NULL,
	[Tax5Per] [decimal](25, 8) NULL,
	[Tax6Per] [decimal](25, 8) NULL,
	[Line_Tax_Exempt_4] [bit] NULL,
	[Line_Tax_Exempt_5] [bit] NULL,
	[Line_Tax_Exempt_6] [bit] NULL,
	[Tare] [float] NULL,
 CONSTRAINT [pkInvoice_Itemized] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Totals]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Totals](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[CustNum] [nvarchar](12) NOT NULL,
	[DateTime] [datetime] NULL,
	[Total_Cost] [money] NOT NULL,
	[Discount] [real] NULL,
	[Total_Price] [money] NOT NULL,
	[Total_Tax1] [money] NOT NULL,
	[Total_Tax2] [money] NOT NULL,
	[Total_Tax3] [money] NOT NULL,
	[Grand_Total] [money] NOT NULL,
	[Amt_Tendered] [money] NULL,
	[Amt_Change] [money] NULL,
	[ShipToUsed] [bit] NOT NULL,
	[InvoiceNotesUsed] [bit] NOT NULL,
	[Status] [nvarchar](1) NOT NULL,
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[Station_ID] [nvarchar](5) NOT NULL,
	[Payment_Method] [nvarchar](4) NOT NULL,
	[Acct_Balance_Due] [money] NULL,
	[Acct_FullyPaid_Date] [datetime] NULL,
	[Taxed_1] [int] NULL,
	[Taxed_Sales] [money] NOT NULL,
	[NonTaxed_Sales] [money] NULL,
	[Tax_Exempt_Sales] [money] NOT NULL,
	[CA_Amount] [money] NOT NULL,
	[CH_Amount] [money] NOT NULL,
	[CC_Amount] [money] NOT NULL,
	[OA_Amount] [money] NOT NULL,
	[GC_Amount] [money] NOT NULL,
	[Tip_Amount] [money] NULL,
	[Old_Balance] [money] NULL,
	[Num_People_Party] [int] NULL,
	[AcctBalanceBefore] [money] NULL,
	[Salesperson] [nvarchar](10) NULL,
	[Dirty] [bit] NOT NULL,
	[Zip_Code] [nvarchar](10) NULL,
	[InvType] [nvarchar](2) NULL,
	[FS_Amount] [money] NULL,
	[Amt_FS_AmtTend] [money] NULL,
	[Amt_FS_Change] [money] NULL,
	[DC_Amount] [money] NULL,
	[OA_Amount_Limited] [money] NULL,
	[Cost_Center_Index] [smallint] NULL,
	[Orig_OnHoldID] [nvarchar](12) NULL,
	[Total_FixedTax] [money] NULL,
	[Total_GC_Sold] [money] NULL,
	[Tax_Rate_ID] [int] NOT NULL,
	[Tax_Rate1_Percent] [int] NULL,
	[Amt_CA_Sec] [money] NULL,
	[Exchange_Rate] [real] NULL,
	[IsLayaway] [bit] NULL,
	[Amt_Deposit] [money] NULL,
	[LAY_Amount] [money] NULL,
	[Total_GC_Free] [money] NULL,
	[MacromatixSyncStatus] [int] NULL,
	[TotalLiability] [money] NULL,
	[ReferenceInvoiceNumber] [bigint] NULL,
	[CourseOrderingProgress] [nvarchar](8) NULL,
	[Amt_CA_Sec_Tendered] [money] NULL,
	[OnlineOrderID] [nvarchar](20) NULL,
	[OrderSource] [int] NULL,
	[OP_Amount] [money] NULL,
	[MP_Amount] [money] NULL,
	[TaxCategory] [int] NULL,
	[MPDiscount_Amount] [money] NULL,
	[Donation_Amount] [money] NOT NULL,
	[Total_UndiscountedSale] [decimal](25, 8) NOT NULL,
	[EBTCashBenefit_Amount] [money] NULL,
	[Split_Check_Type] [int] NOT NULL,
	[OnlineLoyalty_Contact_ID] [nvarchar](25) NULL,
	[Total_Tax4] [money] NULL,
	[Total_Tax5] [money] NULL,
	[Total_Tax6] [money] NULL,
	[AgeVerificationMethod] [int] NOT NULL,
	[AgeVerification] [int] NOT NULL,
	[CP_Amount] [money] NULL,
 CONSTRAINT [pkInvoice_Totals] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[departmentView_View]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[departmentView_View] AS SELECT     I.Store_ID, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) AS datetime, dbo.departments.Description, ROUND(SUM((CC.PricePer * CC.Quantity)    * (1 - I.Discount)), 3) AS totalsales  FROM         dbo.Invoice_Totals AS I INNER JOIN   dbo.Invoice_Itemized AS CC INNER JOIN   dbo.Inventory INNER JOIN   dbo.Departments RIGHT OUTER JOIN   dbo.Categories ON dbo.Categories.Cat_ID = dbo.Departments.SubType AND dbo.Categories.Store_ID = dbo.Departments.Store_ID ON    dbo.Inventory.Dept_ID = dbo.Departments.Dept_ID AND dbo.Inventory.Store_ID = dbo.Departments.Store_ID ON    CC.ItemNum = dbo.Inventory.ItemNum AND CC.Store_ID = dbo.Inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND    I.Store_ID = CC.Store_ID AND CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL AND I.Status = 'C'  GROUP BY I.Store_ID, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), dbo.departments.Description 
GO
/****** Object:  Table [dbo].[CC_Trans]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CC_Trans](
	[Store_ID] [nvarchar](10) NOT NULL,
	[DateTime] [datetime] NOT NULL,
	[Number] [nvarchar](200) NOT NULL,
	[Type] [varchar](50) NULL,
	[TransType] [nvarchar](2) NULL,
	[Expiration] [nvarchar](500) NULL,
	[Amount] [money] NULL,
	[Approval] [nvarchar](max) NOT NULL,
	[Reference] [nvarchar](60) NULL,
	[CREType] [int] NULL,
	[CRENumber] [bigint] NOT NULL,
	[TipAmount] [money] NULL,
	[Sub_Invoice_Number] [int] NOT NULL,
	[CardType] [smallint] NULL,
	[Tip_Applied] [bit] NOT NULL,
	[Merchant] [smallint] NULL,
	[TroutD] [nvarchar](max) NOT NULL,
	[PostAuthReferenceNumber] [nvarchar](max) NOT NULL,
	[OrderId] [nvarchar](max) NOT NULL,
	[ResponseMessage] [nvarchar](200) NULL,
	[AccountType] [int] NULL,
	[Language] [nvarchar](1) NULL,
	[AppliedGratuity] [money] NOT NULL,
	[TruncatedCardNumber] [nvarchar](25) NULL,
	[PaymentMethod] [int] NULL,
	[CashBack] [money] NULL,
	[TerminalNumber] [nvarchar](25) NULL,
	[BatchNumber] [int] NULL,
	[BatchRecordNumber] [int] NULL,
	[ErrorMessage] [nvarchar](40) NULL,
	[ACI] [nvarchar](max) NULL,
	[VisaResponseCode] [nvarchar](15) NULL,
	[CardEntrySource] [int] NULL,
	[TraceNumber] [nvarchar](50) NULL,
	[SequenceNumber] [int] NULL,
	[IsPrePaidCard] [int] NULL,
	[PreAuthAmount] [money] NOT NULL,
	[Settlement_Status] [int] NULL,
	[VoucherNumber] [nvarchar](30) NULL,
	[appLabel] [nvarchar](16) NULL,
	[appPreferredName] [nvarchar](16) NULL,
	[cardPlan] [nvarchar](16) NULL,
	[emv_aid] [nvarchar](32) NULL,
	[arqc_tvr] [nvarchar](25) NULL,
	[arqc] [nvarchar](16) NULL,
	[tc_acc_tvr] [nvarchar](max) NULL,
	[tc_acc] [nvarchar](16) NULL,
	[supplementalData] [nvarchar](1000) NULL,
	[cvm_Indicator] [nvarchar](2) NULL,
	[ResponseMessage2] [nvarchar](40) NULL,
	[Token] [nvarchar](max) NOT NULL,
	[First_Name] [nvarchar](500) NULL,
	[Last_Name] [nvarchar](500) NULL,
	[tvr_Indicator] [nvarchar](100) NULL,
	[tsi_Indicator] [nvarchar](100) NULL,
	[appTrans_Counter] [nvarchar](100) NULL,
	[formFactor_Indicator] [nvarchar](100) NULL,
	[issuer_ApplicationData] [nvarchar](100) NULL,
	[chip_UnpredictableNumber] [nvarchar](100) NULL,
	[terminal_SerialNumber] [nvarchar](100) NULL,
	[appTransType] [nvarchar](10) NULL,
	[dedicated_FileName] [nvarchar](100) NULL,
	[currency_Code] [nvarchar](25) NULL,
	[pan_SequenceNumber] [nvarchar](25) NULL,
	[appExpirationDate] [nvarchar](25) NULL,
	[country_Code] [nvarchar](10) NULL,
	[tcp_Indicator] [nvarchar](100) NULL,
	[terminal_type] [nvarchar](10) NULL,
	[apptrans_SequenceCounter] [nvarchar](25) NULL,
	[appUsageControl] [nvarchar](50) NULL,
	[apptrans_CategoryCode] [nvarchar](50) NULL,
	[appIdentifierTerminal] [nvarchar](50) NULL,
	[appInterchangeProfile] [nvarchar](100) NULL,
	[cardholderVerificationResult] [nvarchar](100) NULL,
	[customerExclusiveData] [nvarchar](500) NULL,
	[additional_emvdata] [nvarchar](500) NULL,
	[chipAuthorizationCode] [nvarchar](10) NULL,
	[appVersionNumber] [nvarchar](50) NULL,
	[ReceiptInfo] [nvarchar](2000) NULL,
	[IsSignatureUploaded] [bit] NOT NULL,
	[ApprovedAmount] [decimal](25, 8) NOT NULL,
	[SurChargeAmount] [money] NOT NULL,
 CONSTRAINT [pkCC_Trans] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[DateTime] ASC,
	[Number] ASC,
	[CRENumber] ASC,
	[Sub_Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[CreditCardTypesView_View]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[CreditCardTypesView_View] AS  (SELECT     Store_ID, [DateTime], SUM(VisaMCTotal) AS VisaMCTotal, SUM(DiscoverTotal) AS DiscoverTotal, SUM(AmexTotal) AS AmexTotal, SUM(BankDeposit)  AS BankDeposit,SUM(CREDITCARDTOTAL) AS CREDITCARDTOTAL FROM         (SELECT     Store_ID, DateTime, (CASE WHEN [Type] = 'Visa' OR [Type] = 'MC' THEN SUM(CreditCardTotal) ELSE 0 END) AS VisaMCTotal, (CASE WHEN [Type] = 'Disc' THEN SUM(CreditCardTotal)   ELSE 0 END) AS DiscoverTotal, (CASE WHEN [Type] = 'Amex' THEN SUM(CreditCardTotal) ELSE 0 END) AS AmexTotal, SUM(BankDeposit)  AS BankDeposit ,SUM(CREDITCARDTOTAL) AS CREDITCARDTOTAL FROM          (SELECT     i.Store_ID, CAST(FLOOR(CAST(i.[DateTime] AS FLOAT)) AS DATETIME) AS [DateTime], SUM(cc.Amount) AS CreditCardTotal, cc.Type,  SUM(i.CH_Amount + i.CA_Amount) AS BankDeposit  FROM          Invoice_Totals AS i LEFT OUTER JOIN  CC_Trans AS cc ON cc.Store_ID = i.Store_ID AND cc.CRENumber = i.Invoice_Number  WHERE      (CAST(FLOOR(CAST(i.[DateTime] AS FLOAT)) AS DATETIME) IS NOT NULL)  GROUP BY i.Store_ID, CAST(FLOOR(CAST(i.[DateTime] AS FLOAT)) AS DATETIME), cc.Type) AS t1  GROUP BY Store_ID, [DateTime], Type) AS t2  GROUP BY Store_ID, [DateTime])
GO
/****** Object:  Table [dbo].[Gift_Card_Trans]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Gift_Card_Trans](
	[Trans_ID] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Card_ID] [nvarchar](100) NOT NULL,
	[DateTimeStamp] [datetime] NULL,
	[TransType] [int] NULL,
	[Amt] [money] NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[Dirty] [bit] NOT NULL,
	[LineNum] [int] NULL,
	[TroutD] [nvarchar](50) NULL,
	[Approval] [nvarchar](15) NULL,
	[Reference] [nvarchar](60) NULL,
	[VoucherText] [nvarchar](200) NULL,
	[ReceiptText] [nvarchar](400) NOT NULL,
	[BatchNumber] [nvarchar](20) NULL,
	[AdditionalInfo] [nvarchar](10) NULL,
	[TerminalNumber] [nvarchar](10) NULL,
	[OrderId] [nvarchar](34) NULL,
	[CardDescription] [nvarchar](30) NULL,
	[VoucherType] [int] NULL,
	[Responsemessage] [nvarchar](150) NULL,
	[ProcessingType] [int] NULL,
	[CheckType] [int] NULL,
	[CheckReturnNotes] [nvarchar](200) NULL,
	[CheckRetrunFee] [money] NOT NULL,
	[IsPrePaidCard] [int] NULL,
	[InitiatedByReturn] [bit] NULL,
 CONSTRAINT [pkGift_Card_Trans] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Trans_ID] ASC,
	[Card_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Gift_Cards]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Gift_Cards](
	[Card_ID] [nvarchar](100) NOT NULL,
	[Balance] [money] NULL,
	[CustNum] [nvarchar](12) NULL,
	[Open_Date] [datetime] NULL,
	[Exp_Date] [datetime] NULL,
	[Dirty] [bit] NOT NULL,
	[OldStyleAmt] [money] NULL,
	[CardOrSlip] [smallint] NULL,
 CONSTRAINT [pkGift_Cards] PRIMARY KEY CLUSTERED 
(
	[Card_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[giftCardView_View]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[giftCardView_View] AS  ( SELECT     Store_ID, DateTime, SUM(giftcardredeemed) AS giftredetotal, SUM(voucherredeemed) AS voucherredetotal, SUM(freegiftredeemed) AS freegifredeemed,   SUM(giftcardsold) AS giftsoldtotal  FROM         (SELECT     Store_ID, [DateTime], (CASE WHEN [cardorslip] = 0 AND [Transtype] = 1 THEN SUM(total) ELSE 0 END) AS giftcardredeemed,     (CASE WHEN [cardorslip] = 1 AND transtype = 1 THEN SUM(total) ELSE 0 END) AS voucherredeemed, (CASE WHEN [cardorslip] = 2 AND       transtype = 1 THEN SUM(total) ELSE 0 END) AS freegiftredeemed, (CASE WHEN [cardorslip] = 0 AND transtype = 0 THEN SUM(total)       ELSE 0 END) AS giftcardsold          FROM          (SELECT     Invoice_Totals.Store_ID, CAST(FLOOR(CAST(Invoice_Totals.[DateTime] AS FLOAT)) AS DATETIME) AS [DateTime],   SUM(Gift_Card_Trans.Amt) AS Total, Gift_Cards.CardOrSlip, Gift_Card_Trans.TransType      FROM          Invoice_Totals INNER JOIN  Gift_Card_Trans LEFT OUTER JOIN  Gift_Cards ON Gift_Card_Trans.Card_ID = Gift_Cards.Card_ID ON  Invoice_Totals.Invoice_Number = Gift_Card_Trans.Invoice_Number AND  Invoice_Totals.Store_ID = Gift_Card_Trans.Store_ID  WHERE      (Invoice_Totals.Status = 'C') AND (CAST(FLOOR(CAST(Invoice_Totals.[DateTime] AS FLOAT)) AS DATETIME) IS NOT NULL)  GROUP BY Invoice_Totals.Store_ID, CAST(FLOOR(CAST(Invoice_Totals.[DateTime] AS FLOAT)) AS DATETIME),  Gift_Cards.CardOrSlip, Gift_Card_Trans.TransType) AS t1  GROUP BY Store_ID, [DateTime], CardOrSlip, TransType) AS t2  GROUP BY Store_ID, [DateTime])
GO
/****** Object:  Table [dbo].[Setup]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Setup](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Company_Info_1] [nvarchar](30) NULL,
	[Company_Info_2] [nvarchar](30) NULL,
	[Company_Info_3] [nvarchar](30) NULL,
	[Company_Info_4] [nvarchar](30) NULL,
	[Company_Info_5] [nvarchar](30) NULL,
	[Admin_Pass] [nvarchar](50) NULL,
	[Non_Inv_Cost_Perc] [real] NULL,
	[Use_Cost_Perc] [bit] NOT NULL,
	[Invoice_Notes_1] [nvarchar](42) NULL,
	[Invoice_Notes_2] [nvarchar](42) NULL,
	[Invoice_Notes_3] [nvarchar](42) NULL,
	[Invoice_Notes_4] [nvarchar](42) NULL,
	[Invoice_Notes_5] [nvarchar](42) NULL,
	[Invoice_Notes_6] [nvarchar](42) NULL,
	[Invoice_Notes_7] [nvarchar](42) NULL,
	[Invoice_Notes_8] [nvarchar](42) NULL,
	[Invoice_Notes_9] [nvarchar](42) NULL,
	[Invoice_Notes_10] [nvarchar](42) NULL,
	[CCTip] [bit] NOT NULL,
	[Auto_Tip_Size] [int] NULL,
	[Auto_Tip_Perc] [real] NULL,
	[Auto_Tip_Enabled] [int] NULL,
	[Print_Kit_Items] [bit] NOT NULL,
	[Print_Mod_Items] [smallint] NULL,
	[CheckValidation] [int] NULL,
	[Line_Combine] [bit] NOT NULL,
	[PO_Print_Barcodes] [bit] NOT NULL,
	[InetEMail] [nvarchar](50) NULL,
	[Receipt_Equals] [bit] NOT NULL,
	[Average_Cost] [bit] NOT NULL,
	[DPT] [int] NULL,
	[Use_Max_Balance] [bit] NOT NULL,
	[Print_Acct_Balance] [bit] NOT NULL,
	[Print_Amt_Saved] [bit] NOT NULL,
	[Last_Price_Lookup] [bit] NOT NULL,
	[Logo_Type] [int] NULL,
	[Logo_Loc] [nvarchar](100) NULL,
	[Scale_Tear] [real] NULL,
	[TS_Use_Decimal] [bit] NOT NULL,
	[Round_Nearest_Nickel] [bit] NOT NULL,
	[POOrder] [int] NULL,
	[Use_Barcode_Scale] [bit] NOT NULL,
	[CostMarkUpPerc] [real] NULL,
	[Round_Invoice] [smallint] NULL,
	[Tax_ID] [nvarchar](25) NULL,
	[Store_Email] [nvarchar](50) NULL,
	[Serial_Track_Incoming] [bit] NOT NULL,
	[Rentals_Prompt_Days] [bit] NOT NULL,
	[AcctNum] [nvarchar](40) NULL,
	[Prevent_PO_Excess] [bit] NOT NULL,
	[Track_PO_DelNum] [bit] NOT NULL,
	[Serial_Allow_Duplicates] [bit] NOT NULL,
	[Customer_Price_Lookup] [bit] NOT NULL,
	[Num_Days_GC_Exp] [int] NULL,
	[ID_Valid_Days] [int] NULL,
	[Use_MixNMatch] [bit] NOT NULL,
	[PromptRentSell] [bit] NOT NULL,
	[Req_InvIn_Desc] [bit] NOT NULL,
	[Rentals_Unique] [bit] NOT NULL,
	[AutoPayARInv] [bit] NOT NULL,
	[PrintARInvSig] [bit] NOT NULL,
	[CO_Req_Tips] [bit] NOT NULL,
	[CO_Close_OnHold] [bit] NOT NULL,
	[Log_Returns] [smallint] NULL,
	[Bonus_to_Dollars] [bit] NOT NULL,
	[Deduct_Ingredients] [smallint] NULL,
	[Kitchen_Info] [smallint] NULL,
	[Receipt_CC_Notes] [bit] NOT NULL,
	[Clockout_Receipt] [bit] NOT NULL,
	[Combine_Checks] [smallint] NULL,
	[Shift_CashTips_Disinclude_CashCount] [bit] NOT NULL,
	[Profit_Center_Takeout] [int] NULL,
	[Profit_Center_Delivery] [int] NULL,
	[Profit_Center_OpenTabs] [int] NULL,
	[Check_ID1_Age] [smallint] NULL,
	[Check_ID2_Age] [smallint] NULL,
	[Check_ID1_Msg] [nvarchar](30) NULL,
	[Check_ID2_Msg] [nvarchar](30) NULL,
	[Check_ID1_BDayPrompt] [bit] NOT NULL,
	[OnTheFly_Def_Vendor] [nvarchar](12) NULL,
	[OnTheFly_Def_Dept] [nvarchar](8) NULL,
	[OnTheFly_Def_Desc] [nvarchar](30) NULL,
	[Tax_On_Tips] [bit] NOT NULL,
	[Pullbacks_Use_TimeClock] [bit] NOT NULL,
	[OnTheFly_Def_Taxed] [smallint] NULL,
	[OnTheFly_Def_Foodstamp] [bit] NOT NULL,
	[OnTheFly_Prompt_Cost] [bit] NOT NULL,
	[SecCurr_Exchange_Rate] [real] NULL,
	[SecCurr_Desc] [nvarchar](20) NULL,
	[SecCurr_Symbol] [nvarchar](5) NULL,
	[CC_Floor_Amt] [money] NULL,
	[Cash_Alert_Level] [money] NULL,
	[Cash_Lockup_Level] [money] NULL,
	[Tips_Deny_Settle] [bit] NOT NULL,
	[Global_Transfer_Markup] [real] NULL,
	[Use_Global_Transfer_Markup] [bit] NOT NULL,
	[Tips_Keep_Check_Open] [bit] NOT NULL,
	[Invoice_Notes_Top] [ntext] NULL,
	[Print_Dept_Notes] [bit] NOT NULL,
	[Store_Refund_Media] [smallint] NULL,
	[Store_Credit_Notes] [ntext] NULL,
	[Large_Purchase] [money] NULL,
	[CheckDLFloor] [money] NULL,
	[CheckPNFloor] [money] NULL,
	[Ent_Add_Missing_Records] [bit] NULL,
	[Receipt_Combine_Lines] [bit] NULL,
	[Scale_Tare2] [float] NULL,
	[Layway_Type] [smallint] NULL,
	[Layway_Deposit_Type] [smallint] NULL,
	[Layway_Deposit_Minimum] [float] NULL,
	[Layway_Cancellation_Days] [smallint] NULL,
	[Layway_Pre_Cancellation_Type] [smallint] NULL,
	[Layway_Pre_Cancellation_Fee] [float] NULL,
	[Layway_Post_Cancellation_Type] [smallint] NULL,
	[Layway_Post_Cancellation_Fee] [float] NULL,
	[Layway_Allow_Partial_Pickup] [bit] NULL,
	[EnforceProperties] [bit] NULL,
	[ValidReturnWindow] [smallint] NULL,
	[CashDrawerSelectionType] [smallint] NULL,
	[WorkWeekStartDay] [smallint] NULL,
	[LogExceptions] [smallint] NULL,
	[CancelledCheckFee] [money] NULL,
	[AddItemHideTS] [bit] NULL,
	[AllowStandaloneModifiers] [bit] NULL,
	[DefaultDrawerStart] [money] NULL,
	[Use_Dept_Cost_Calculation] [bit] NULL,
	[Store_Description] [nvarchar](50) NULL,
	[Square_Footage] [bigint] NULL,
	[Population_Served] [bigint] NULL,
	[DeliveryAssignmentOrder] [int] NULL,
	[ReceiptCustInfo] [int] NULL,
	[ArchiveData_NumDays] [int] NULL,
	[LoginCheckExitPerm] [bit] NULL,
	[selectPizzaBy] [int] NULL,
	[donationNotes] [ntext] NULL,
	[printToppingsOnOneLine] [bit] NULL,
	[Invoice_Discounts_X_Level] [real] NULL,
	[Drawer_OverShort_Recounts] [int] NULL,
	[EBT_Exempt_Tax] [bit] NULL,
	[Shift_Assignment] [int] NULL,
	[EOD_Allowance_TimeClock] [int] NULL,
	[EOD_Allowance_OnHold] [int] NULL,
	[EOD_Require_MoneyCount] [int] NULL,
	[Drawer_Count_Threshhold_Recount] [real] NULL,
	[NumStoreCreditReceipts] [int] NULL,
	[LayawayForceDepositMinimum] [int] NULL,
	[HideInvoiceQuantityTextbox] [bit] NOT NULL,
	[HideInvoiceChangeQuantityButton] [bit] NOT NULL,
	[ChargeForToppingSubstitutions] [bit] NOT NULL,
	[ViewableReportHistory] [int] NULL,
	[Address] [nvarchar](30) NULL,
	[City] [nvarchar](30) NULL,
	[State] [nvarchar](20) NULL,
	[ZipCode] [nvarchar](10) NULL,
	[PrintDirections] [int] NULL,
	[PrintDirectionsMethod] [int] NULL,
	[PrintReturnDirections] [bit] NULL,
	[PrintCustomerInfoOnKitchenPrinter] [bit] NULL,
	[ParentTemplateID] [nvarchar](10) NULL,
	[IsTemplate] [bit] NULL,
	[GC_Gateway_port] [nvarchar](10) NULL,
	[MaxCashback] [money] NULL,
	[SecurityMethod] [int] NULL,
	[TaxRounding] [int] NULL,
	[ForcedSelectionOrderingProcess] [int] NULL,
	[LayawayEnabled] [bit] NULL,
	[CheaperToppingsFree] [bit] NOT NULL,
	[LineDiscountPromptType] [int] NOT NULL,
	[Batch_Size] [int] NULL,
	[EncryptionHash] [nvarchar](100) NULL,
	[NoCreditCardSignatureBelow] [money] NULL,
	[CreditCardPreAuthAmount] [money] NULL,
	[PreAuthorizePrompt] [int] NULL,
	[PreAuthorizeNewTabPrompt] [int] NULL,
	[Loyalty_Plan_ID] [bigint] NULL,
	[CustomerLoyaltyPrompt] [int] NULL,
	[AutoCombo] [bit] NULL,
	[PrintPaidStatusInKitchenReceipt] [bit] NOT NULL,
	[WhenRemovingADefaultTopping] [int] NOT NULL,
	[Perform_Batchsettlement_OnEndofDay] [bit] NULL,
	[StdInvPercentAllowed] [real] NULL,
	[OvertimeCalculationMethod] [int] NULL,
	[OrderPreparationTime] [int] NULL,
	[Store_Declaration_Form] [ntext] NULL,
	[ScaleBarcodeMethod] [int] NULL,
	[ScaleBarcodeFormat] [nvarchar](100) NULL,
	[ShowRestaurantScanTextbox] [bit] NULL,
	[PromptPayoutItemNum] [bit] NULL,
	[Personal_Check_Return_Notes] [ntext] NULL,
	[Corporate_Check_Return_Notes] [ntext] NULL,
	[UpdateItemVendorCostFromPO] [bit] NULL,
	[CCTipPercWithheld] [real] NULL,
	[DeliveryDirectionsProvider] [int] NULL,
	[AutoBatchSettlementStatus_EmailId] [nvarchar](50) NULL,
	[AutoBatchSettlement_Time] [nvarchar](20) NULL,
	[AutoBatchSettlementStatus] [bit] NULL,
	[SubtractDrawerStartFromDeposits] [bit] NULL,
	[StationProcessingMobileTransactions] [nvarchar](2) NULL,
	[Round_Cash_Transactions] [tinyint] NOT NULL,
	[Phone_1] [nvarchar](15) NULL,
	[Prompt_Distributor] [bit] NULL,
	[Prompt_OutOfDate] [bit] NULL,
	[Password_Hash] [nvarchar](500) NULL,
	[Salt_Key] [nvarchar](500) NULL,
	[Locked_Time] [datetime] NULL,
	[company_identifier] [nvarchar](20) NULL,
	[payroll_export_type] [int] NOT NULL,
	[Check_ID_Expiration] [bit] NULL,
 CONSTRAINT [pkSetup] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[InvoiceView_View]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[InvoiceView_View] AS  (SELECT     Invoice_Totals.Store_ID, Setup.Store_Description, COUNT(DISTINCT Invoice_Totals.Invoice_Number) AS customers,  CAST(FLOOR(CAST(Invoice_Totals.[DateTime] AS FLOAT)) AS DATETIME) AS [DateTime],  ROUND(SUM((Invoice_Itemized.PricePer * Invoice_Itemized.Quantity) * (1 - Invoice_Totals.Discount)), 3) AS totalsales,  SUM(Invoice_Totals.Taxed_Sales) AS taxedsales, SUM(Invoice_Totals.Tax_Exempt_Sales) AS taxExempt,  ROUND(SUM((Invoice_Itemized.Tax1Per + Invoice_Itemized.Tax2Per + Invoice_Itemized.Tax3Per) * (1 - Invoice_Totals.Discount)), 3)  AS totalsalestax, SUM(Invoice_Totals.NonTaxed_Sales) AS nontaxed, SUM(Invoice_Totals.CA_Amount) AS totalcash  FROM         Invoice_Totals INNER JOIN   Invoice_Itemized ON Invoice_Itemized.Invoice_Number = Invoice_Totals.Invoice_Number AND  Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID INNER JOIN  Setup ON Setup.Store_ID = Invoice_Totals.Store_ID  WHERE     (Invoice_Totals.Status = 'C') AND (CAST(FLOOR(CAST(Invoice_Totals.[DateTime] AS FLOAT)) AS DATETIME) IS NOT NULL)  GROUP BY CAST(FLOOR(CAST(Invoice_Totals.[DateTime] AS FLOAT)) AS DATETIME), Invoice_Totals.Store_ID, Setup.Store_Description)
GO
/****** Object:  Table [dbo].[End_Of_Day]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[End_Of_Day](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Close_Out_Index] [int] NOT NULL,
	[Actual_Cash] [money] NULL,
	[StartDateTime] [datetime] NULL,
	[EndDateTime] [datetime] NULL,
	[OverShort] [money] NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[Actual_C2] [money] NOT NULL,
	[OverShort_C2] [money] NOT NULL,
 CONSTRAINT [pkEnd_Of_Day] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Close_Out_Index] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[netCashView_View]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[netCashView_View] AS  (SELECT     Store_ID, SUM(Actual_Cash) AS netcash, CAST(FLOOR(CAST(EndDateTime AS FLOAT)) AS DATETIME) AS DateTime  FROM End_Of_Day GROUP BY Store_ID, CAST(FLOOR(CAST(EndDateTime AS FLOAT)) AS DATETIME))
GO
/****** Object:  Table [dbo].[Payouts]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Payouts](
	[ID] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[DateTime] [datetime] NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Amount] [money] NULL,
	[Station_ID] [nvarchar](5) NOT NULL,
	[Description] [nvarchar](35) NULL,
	[Payment_Method] [nvarchar](4) NULL,
	[Type] [smallint] NULL,
	[Override_ID] [nvarchar](10) NULL,
	[ItemNum] [nvarchar](20) NULL,
 CONSTRAINT [pkPayouts] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[pettycashView_View]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[pettycashView_View] AS  (SELECT     Store_ID, CAST(FLOOR(CAST([DateTime] AS FLOAT)) AS DATETIME) AS [DateTime], SUM(Amount) AS pettycash  FROM Payouts WHERE     (Vendor_Number = 'petty cash')  GROUP BY Store_ID, CAST(FLOOR(CAST([DateTime] AS FLOAT)) AS DATETIME))
GO
/****** Object:  Table [dbo].[AccountingInterfaceSettings]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AccountingInterfaceSettings](
	[RowID] [uniqueidentifier] NOT NULL,
	[Store_ID] [nvarchar](10) NULL,
	[RecordType] [int] NULL,
	[Field1] [nvarchar](50) NULL,
	[Field2] [nvarchar](50) NULL,
	[Field3] [nvarchar](50) NULL,
	[Field4] [nvarchar](50) NULL,
 CONSTRAINT [pkAccountingInterfaceSettings] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Admin_Password_History]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Admin_Password_History](
	[Store_Id] [nvarchar](10) NOT NULL,
	[Password] [nvarchar](500) NULL,
	[Salt_Key] [nvarchar](500) NULL,
	[CreationDate] [datetime] NOT NULL,
 CONSTRAINT [pk_Admin_Password_History] PRIMARY KEY CLUSTERED 
(
	[Store_Id] ASC,
	[CreationDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Admin_Password_Reset]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Admin_Password_Reset](
	[Store_Id] [nvarchar](10) NOT NULL,
	[Question_1] [nvarchar](500) NULL,
	[Answer_1] [nvarchar](500) NULL,
	[Salt_1] [nvarchar](500) NULL,
	[Question_2] [nvarchar](500) NULL,
	[Answer_2] [nvarchar](500) NULL,
	[Salt_2] [nvarchar](500) NULL,
	[Question_3] [nvarchar](500) NULL,
	[Answer_3] [nvarchar](500) NULL,
	[Salt_3] [nvarchar](500) NULL,
	[Modified_Time] [datetime] NULL,
 CONSTRAINT [pk_Admin_Password_Reset] PRIMARY KEY CLUSTERED 
(
	[Store_Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AR_Accounting_Transaction]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AR_Accounting_Transaction](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Trans_ID] [bigint] NOT NULL,
	[Txn_Id] [nvarchar](20) NULL,
	[EditSequence] [nvarchar](20) NULL,
 CONSTRAINT [pkAR_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Trans_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AR_Signatures]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AR_Signatures](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Trans_ID] [bigint] NOT NULL,
	[Signature] [ntext] NULL,
	[LineNum] [int] NULL,
	[Index] [bigint] NULL,
 CONSTRAINT [pkAR_Signatures] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Trans_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AR_Trans_Details]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AR_Trans_Details](
	[Trans_ID] [bigint] NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[Amount] [money] NULL,
	[Prev_Inv_Balance] [money] NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[targetStore_ID] [nvarchar](10) NULL,
	[Datetime] [datetime] NULL,
	[ID] [bigint] NOT NULL,
	[PID] [bigint] NOT NULL,
 CONSTRAINT [pkAR_Trans_Details] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AR_Transactions]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AR_Transactions](
	[Trans_ID] [bigint] NOT NULL,
	[DateTime] [datetime] NOT NULL,
	[Cashier_ID] [nvarchar](50) NULL,
	[CustNum] [nvarchar](12) NOT NULL,
	[Trans_Type] [nvarchar](2) NOT NULL,
	[Prev_Cust_Balance] [money] NULL,
	[Prev_Inv_Balance] [money] NULL,
	[Trans_Amount] [money] NOT NULL,
	[Payment_Method] [nvarchar](4) NULL,
	[Payment_Info] [nvarchar](20) NULL,
	[Description] [nvarchar](38) NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Dirty] [bit] NOT NULL,
	[Station_ID] [nvarchar](5) NULL,
	[Payment_Type] [smallint] NULL,
	[AmountRemaining] [money] NULL,
	[Canceled_Trans] [bigint] NULL,
 CONSTRAINT [pkAR_Transactions] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Trans_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BackOrders]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BackOrders](
	[BONum] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[DateTime] [datetime] NULL,
	[CustNum] [nvarchar](12) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Quan] [float] NULL,
	[Type] [nvarchar](2) NOT NULL,
	[Status] [nvarchar](1) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[FillDate] [datetime] NULL,
	[Dirty] [bit] NOT NULL,
 CONSTRAINT [pkBackOrders] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[BONum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BumpBarRoutes]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BumpBarRoutes](
	[ObjectID] [uniqueidentifier] NOT NULL,
	[Store_ID] [nvarchar](10) NULL,
	[Name] [nvarchar](30) NULL,
	[Route] [nvarchar](75) NULL,
 CONSTRAINT [pkBumpBarRoutes] PRIMARY KEY CLUSTERED 
(
	[ObjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BumpBars]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BumpBars](
	[Store_ID] [nvarchar](10) NOT NULL,
	[BumpBarID] [int] NOT NULL,
	[NumberOfPanels] [int] NULL,
	[DelayedOrderColor1] [int] NULL,
	[DelayedOrderColor2] [int] NULL,
	[DelayedOrderColor3] [int] NULL,
	[DelayedTime1] [int] NULL,
	[DelayedTime2] [int] NULL,
	[DelayedTime3] [int] NULL,
	[DefaultBackGround] [int] NULL,
	[DefaultForeGround] [int] NULL,
	[BeepOnNewOrder] [bit] NULL,
	[Enabled] [bit] NULL,
	[DisplayCashierID] [bit] NULL,
	[IPAddress] [nvarchar](100) NULL,
	[Port] [int] NULL,
	[BumpBarController] [int] NULL,
	[NumBumpBarsControlled] [int] NULL,
	[ObjectID] [nvarchar](40) NOT NULL,
	[Name] [nvarchar](10) NULL,
	[NumberOfPanelRows] [int] NULL,
	[PanelHeaderBackColor] [int] NULL,
	[PanelHeaderForeColor] [int] NULL,
	[ScreenWidth] [int] NULL,
 CONSTRAINT [pkBumpBars] PRIMARY KEY CLUSTERED 
(
	[ObjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CardPaymentBatches]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CardPaymentBatches](
	[Store_ID] [nvarchar](10) NOT NULL,
	[BatchNumber] [int] NOT NULL,
	[ApprovalNumber] [nvarchar](20) NULL,
	[BatchTransactionCount] [int] NULL,
	[BatchTransactionAmount] [money] NULL,
	[TerminalNumber] [nvarchar](20) NOT NULL,
	[Datetime] [datetime] NULL,
	[Settlement_Status] [int] NULL,
	[RowID] [uniqueidentifier] NOT NULL,
 CONSTRAINT [pkCardPaymentBatches] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Categories_Reference]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Categories_Reference](
	[ID] [int] NULL,
	[Cat_ID] [nvarchar](8) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkCategories_Reference] PRIMARY KEY CLUSTERED 
(
	[Cat_ID] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CH_Trans]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CH_Trans](
	[Store_ID] [nvarchar](10) NOT NULL,
	[CheckNum] [nvarchar](20) NOT NULL,
	[AcctNum] [nvarchar](20) NULL,
	[RoutNum] [nvarchar](20) NULL,
	[Trans_Number] [bigint] NOT NULL,
	[Amount] [money] NULL,
	[Trans_Type] [int] NOT NULL,
	[DLNumber] [nvarchar](15) NULL,
	[PhoneNum] [nvarchar](15) NULL,
	[DLStateCode] [nvarchar](5) NULL,
	[TroutD] [nvarchar](50) NULL,
	[eCheck] [bit] NULL,
	[Sub_Invoice_Number] [int] NOT NULL,
	[BatchNumber] [int] NULL,
	[BatchRecordNumber] [int] NULL,
	[SequenceNumber] [int] NULL,
	[Approval] [nvarchar](30) NULL,
	[TransType] [nvarchar](2) NULL,
	[Settlement_Status] [int] NULL,
	[ErrorMessage] [nvarchar](40) NULL,
	[TerminalNumber] [nvarchar](25) NULL,
	[DateTime] [datetime] NULL,
	[CheckRetrunFee] [money] NULL,
	[CheckType] [int] NULL,
	[CheckReturnNotes] [ntext] NULL,
 CONSTRAINT [pkCH_Trans] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[CheckNum] ASC,
	[Trans_Number] ASC,
	[Trans_Type] ASC,
	[Sub_Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ChoiceItems_Properties]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ChoiceItems_Properties](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Value_ID] [int] NOT NULL,
 CONSTRAINT [pkChoiceItems_Properties] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Value_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Cost_Centers]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Cost_Centers](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cost_Center_Index] [int] NULL,
	[Description] [nvarchar](20) NOT NULL,
 CONSTRAINT [pkCost_Centers] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Description] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Coupon_Layout]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Coupon_Layout](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Coupon_Index] [int] NULL,
	[Line1] [nvarchar](40) NULL,
	[Line2] [nvarchar](40) NULL,
	[Line3] [nvarchar](40) NULL,
	[Line4] [nvarchar](40) NULL,
	[Line5] [nvarchar](40) NULL,
 CONSTRAINT [pkCoupon_Layout] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer](
	[CustNum] [nvarchar](12) NOT NULL,
	[First_Name] [nvarchar](15) NULL,
	[Last_Name] [nvarchar](15) NOT NULL,
	[Company] [nvarchar](30) NULL,
	[Address_1] [nvarchar](30) NULL,
	[Address_2] [nvarchar](30) NULL,
	[City] [nvarchar](20) NULL,
	[State] [nvarchar](12) NULL,
	[Zip_Code] [nvarchar](10) NULL,
	[Phone_1] [nvarchar](15) NULL,
	[Phone_2] [nvarchar](15) NULL,
	[CC_Type] [nvarchar](5) NULL,
	[CC_Num] [nvarchar](500) NULL,
	[CC_Exp] [nvarchar](500) NULL,
	[Discount_Level] [nvarchar](1) NOT NULL,
	[Discount_Percent] [real] NOT NULL,
	[Acct_Open_Date] [datetime] NULL,
	[Acct_Close_Date] [datetime] NULL,
	[Acct_Balance] [money] NULL,
	[Acct_Max_Balance] [money] NULL,
	[Bonus_Plan_Member] [bit] NOT NULL,
	[Bonus_Points] [int] NULL,
	[Tax_Exempt] [bit] NOT NULL,
	[Member_Exp] [datetime] NULL,
	[Dirty] [bit] NOT NULL,
	[Phone_3] [nvarchar](15) NULL,
	[Phone_4] [nvarchar](15) NULL,
	[EMail] [nvarchar](50) NULL,
	[County] [nvarchar](30) NULL,
	[Def_SP] [nvarchar](10) NULL,
	[CreateDate] [datetime] NULL,
	[Referral] [nvarchar](20) NULL,
	[Birthday] [datetime] NULL,
	[Last_Birthday_Bonus] [datetime] NULL,
	[Last_Visit] [datetime] NULL,
	[Require_PONum] [bit] NOT NULL,
	[Max_Charge_NumDays] [int] NULL,
	[Max_Charge_Amount] [money] NULL,
	[License_Num] [nvarchar](20) NULL,
	[ID_Last_Checked] [datetime] NULL,
	[Next_Start_Date] [datetime] NULL,
	[Checking_AcctNum] [nvarchar](20) NULL,
	[PrintNotes] [bit] NOT NULL,
	[Loyalty_Plan_ID] [bigint] NULL,
	[Tax_Rate_ID] [int] NULL,
	[Bill_To_Name] [nvarchar](30) NULL,
	[Contact_1] [nvarchar](30) NULL,
	[Contact_2] [nvarchar](30) NULL,
	[Terms] [nvarchar](15) NULL,
	[Resale_Num] [nvarchar](15) NULL,
	[Last_Coupon] [datetime] NULL,
	[Account_Type] [smallint] NULL,
	[ChargeAtCost] [bit] NULL,
	[Disabled] [bit] NULL,
	[ImagePath] [nvarchar](255) NULL,
	[License_ExpDate] [datetime] NULL,
	[TaxID] [nvarchar](20) NULL,
	[SecretCode] [nvarchar](10) NULL,
	[OnlineUserName] [nvarchar](20) NULL,
	[OnlinePassword] [nvarchar](40) NULL,
	[Token] [nvarchar](250) NULL,
	[MaskedCardNumber] [nvarchar](250) NULL,
	[Attn] [nvarchar](30) NULL,
	[DueDate] [datetime] NULL,
	[Token_ReferenceNum] [nvarchar](250) NULL,
 CONSTRAINT [pkCustomer] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Accounting_Transaction]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Accounting_Transaction](
	[CustNum] [nvarchar](12) NOT NULL,
	[EditSequence] [nvarchar](20) NULL,
 CONSTRAINT [pkCustomer_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Authorized]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Authorized](
	[CustNum] [nvarchar](12) NOT NULL,
	[Member] [nvarchar](30) NOT NULL,
	[Dirty] [bit] NOT NULL,
 CONSTRAINT [pkCustomer_Authorized] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC,
	[Member] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Auto]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Auto](
	[CustNum] [nvarchar](12) NOT NULL,
	[License] [nvarchar](10) NOT NULL,
	[Make] [nvarchar](15) NULL,
	[Model] [nvarchar](15) NULL,
 CONSTRAINT [pkCustomer_Auto] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC,
	[License] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Events]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Events](
	[CustNum] [nvarchar](12) NOT NULL,
	[Event_Date] [datetime] NOT NULL,
	[Event_Desc] [nvarchar](15) NOT NULL,
	[Dirty] [bit] NOT NULL,
 CONSTRAINT [pkCustomer_Events] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Gift_Registry]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Gift_Registry](
	[Registry_ID] [nvarchar](15) NOT NULL,
	[CustNum] [nvarchar](12) NOT NULL,
	[Description] [nvarchar](20) NULL,
	[Event_Date] [datetime] NULL,
	[Date_Created] [datetime] NULL,
	[Dirty] [bit] NOT NULL,
 CONSTRAINT [pkCustomer_Gift_Registry] PRIMARY KEY CLUSTERED 
(
	[Registry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Gift_Registry_Items]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Gift_Registry_Items](
	[Registry_ID] [nvarchar](15) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Quan_Req] [decimal](25, 8) NULL,
	[Quan_Purch] [decimal](25, 8) NULL,
 CONSTRAINT [pkCustomer_Gift_Registry_Items] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Registry_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Notes]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Notes](
	[CustNum] [nvarchar](12) NOT NULL,
	[Notes] [ntext] NULL,
 CONSTRAINT [pkCustomer_Notes] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Properties]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Properties](
	[CustNum] [nvarchar](12) NOT NULL,
	[Value_ID] [smallint] NOT NULL,
 CONSTRAINT [pkCustomer_Properties] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC,
	[Value_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Reference]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Reference](
	[ID] [int] NULL,
	[CustNum] [nvarchar](12) NOT NULL,
 CONSTRAINT [pkCustomer_Reference] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_ShipTos]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_ShipTos](
	[CustNum] [nvarchar](12) NOT NULL,
	[First_Name] [nvarchar](15) NULL,
	[Last_Name] [nvarchar](15) NULL,
	[Company] [nvarchar](30) NULL,
	[Address_1] [nvarchar](30) NULL,
	[Address_2] [nvarchar](30) NULL,
	[City] [nvarchar](20) NULL,
	[State] [nvarchar](12) NULL,
	[Zip_Code] [nvarchar](10) NULL,
	[Phone] [nvarchar](15) NULL,
	[Dirty] [bit] NOT NULL,
	[County] [nvarchar](30) NULL,
	[DeliveryAddressSpecialInstructions] [nvarchar](100) NULL,
 CONSTRAINT [pkCustomer_ShipTos] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Stores]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Stores](
	[CustNum] [nvarchar](12) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkCustomer_Stores] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Customer_Swipes]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer_Swipes](
	[CustNum] [nvarchar](12) NOT NULL,
	[Swipe_ID] [nvarchar](50) NOT NULL,
 CONSTRAINT [pkCustomer_Swipes] PRIMARY KEY CLUSTERED 
(
	[CustNum] ASC,
	[Swipe_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Departments_Reference]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Departments_Reference](
	[ID] [int] NULL,
	[Dept_ID] [nvarchar](8) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkDepartments_Reference] PRIMARY KEY CLUSTERED 
(
	[Dept_ID] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[dim_date]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dim_date](
	[date_id] [int] NOT NULL,
	[date] [datetime] NULL,
	[year] [int] NULL,
	[quarter] [int] NULL,
	[month_number_year] [int] NULL,
	[month_number_of_quarter] [int] NULL,
	[week_number_of_year] [int] NULL,
	[week_number_of_quarter] [int] NULL,
	[week_number_of_month] [int] NULL,
	[day_number_of_year] [int] NULL,
	[day_number_of_quarter] [int] NULL,
	[day_number_of_month] [int] NULL,
	[day_number_of_week] [int] NULL,
	[month_name] [nvarchar](30) NULL,
	[month_name_abbreviation] [nvarchar](3) NULL,
	[day_name] [nvarchar](30) NULL,
	[day_name_abbreviation] [nvarchar](3) NULL,
	[YYYYMMDD] [varchar](10) NULL,
	[YYYY/MM/DD] [varchar](10) NULL,
	[mon dd yyyy] [varchar](11) NULL,
	[yyyy-mm-dd] [varchar](11) NULL,
 CONSTRAINT [PK_dim_date] PRIMARY KEY CLUSTERED 
(
	[date_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[dim_time]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dim_time](
	[time_id] [int] NOT NULL,
	[time] [varchar](11) NULL,
	[time_24] [varchar](8) NULL,
	[hour_name] [varchar](5) NULL,
	[minute_name] [varchar](8) NULL,
	[hour_number] [tinyint] NULL,
	[hour_24] [tinyint] NULL,
	[minute_number] [tinyint] NULL,
	[second_number] [tinyint] NULL,
	[am_pm] [char](2) NULL,
	[elapsed_minutes] [int] NULL,
	[elapsed_seconds] [int] NULL,
 CONSTRAINT [PK_dim_time] PRIMARY KEY CLUSTERED 
(
	[time_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Donation_Itemized]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Donation_Itemized](
	[Donation_Number] [bigint] NOT NULL,
	[Line_Number] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NULL,
	[Quantity] [int] NULL,
	[Value_Per] [money] NULL,
 CONSTRAINT [pkDonation_Itemized] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Donation_Number] ASC,
	[Line_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Donation_Totals]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Donation_Totals](
	[Donation_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Station_ID] [nvarchar](5) NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[DateTime] [datetime] NULL,
	[Total_Value] [money] NULL,
	[Status] [nvarchar](1) NULL,
	[CustNum] [nvarchar](12) NULL,
 CONSTRAINT [pkDonation_Totals] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Donation_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DVRs]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DVRs](
	[ObjectID] [uniqueidentifier] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[IPAddress] [nvarchar](15) NULL,
	[Port] [int] NULL,
	[SerialPort] [int] NULL,
 CONSTRAINT [pkDVRs] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ObjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Employee]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Employee](
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[CustNum] [nvarchar](12) NULL,
	[Dept_ID] [nvarchar](8) NULL,
	[Password] [nvarchar](50) NULL,
	[Swipe_ID] [nvarchar](50) NULL,
	[Hourly_Wage] [money] NULL,
	[Form_Color] [int] NOT NULL,
	[CDL] [nvarchar](25) NULL,
	[Name] [nvarchar](30) NULL,
	[CFA_Setup_Company] [nvarchar](1) NOT NULL,
	[CFA_Setup_Tax] [nvarchar](1) NOT NULL,
	[CFA_Setup_Bonus] [nvarchar](1) NOT NULL,
	[CFA_Setup_Accounting] [nvarchar](1) NOT NULL,
	[CFA_Setup_Discounts] [nvarchar](1) NOT NULL,
	[CFA_Setup_Display] [nvarchar](1) NOT NULL,
	[CFA_Setup_DefPrinter] [nvarchar](1) NOT NULL,
	[CFA_Inven_Add] [nvarchar](1) NOT NULL,
	[CFA_Inven_Edit] [nvarchar](1) NOT NULL,
	[CFA_Vendors_Add] [nvarchar](1) NOT NULL,
	[CFA_Vendors_Edit] [nvarchar](1) NOT NULL,
	[CFA_Depts_Add] [nvarchar](1) NOT NULL,
	[CFA_Depts_Edit] [nvarchar](1) NOT NULL,
	[CFA_Inven_TickVouch] [nvarchar](1) NOT NULL,
	[CFA_Cust_add] [nvarchar](1) NOT NULL,
	[CFA_Cust_Edit] [nvarchar](1) NOT NULL,
	[CFA_Reports_Display] [nvarchar](1) NOT NULL,
	[CFA_Reports_DDR] [nvarchar](1) NOT NULL,
	[CFA_Reports_Print] [nvarchar](1) NOT NULL,
	[CFA_Invoice_Discount] [nvarchar](1) NOT NULL,
	[CFA_Invoice_PriceChange] [nvarchar](1) NOT NULL,
	[CFA_Invoice_DeleteItems] [nvarchar](1) NOT NULL,
	[CFA_Invoice_Void] [nvarchar](1) NOT NULL,
	[CFA_CRE_Acct] [nvarchar](1) NOT NULL,
	[CFA_CRE_Exit] [nvarchar](1) NOT NULL,
	[Dirty] [bit] NOT NULL,
	[Last_DDR] [datetime] NULL,
	[CFA_Display_Balance] [nvarchar](1) NULL,
	[CFA_Refund_Item] [nvarchar](1) NULL,
	[Disp_Pay_Option] [bit] NOT NULL,
	[Disp_Item_Option] [bit] NOT NULL,
	[EmpName] [nvarchar](30) NULL,
	[CFA_Receive_Items] [nvarchar](1) NULL,
	[CFA_DO_POS] [nvarchar](1) NULL,
	[CFA_INSTANT_POS] [nvarchar](1) NULL,
	[Section_ID] [nvarchar](15) NULL,
	[CFA_Other_Tables] [nvarchar](1) NULL,
	[CFA_Accept_Cash] [nvarchar](1) NULL,
	[CFA_TRANSFER_NOSWIPE] [nvarchar](1) NULL,
	[CFA_ADD_CCTIPS] [nvarchar](1) NULL,
	[Disabled] [bit] NOT NULL,
	[CFA_PRINT_HOLD] [nvarchar](1) NULL,
	[CFA_Open_Cash_Drawer] [nvarchar](1) NULL,
	[CCTipsNow] [bit] NOT NULL,
	[ReqClockIn] [bit] NOT NULL,
	[CFA_Split_Checks] [nvarchar](1) NULL,
	[CFA_Transfer_Tables] [nvarchar](1) NULL,
	[CFA_Extra_Item] [nvarchar](1) NULL,
	[CFA_Tax_Exempt] [nvarchar](1) NULL,
	[CFA_GC_Sell] [nvarchar](1) NULL,
	[CFA_GC_Redeem] [nvarchar](1) NULL,
	[CFA_SELL_SPECIAL_ITEM] [nvarchar](1) NULL,
	[CFA_VENDOR_PAYOUT] [nvarchar](1) NULL,
	[CFA_APPLY_GRATUITY] [nvarchar](1) NULL,
	[First_Name] [nvarchar](15) NULL,
	[Middle_Name] [nvarchar](15) NULL,
	[Last_Name] [nvarchar](20) NULL,
	[SSN] [nvarchar](20) NULL,
	[Address_1] [nvarchar](30) NULL,
	[Address_2] [nvarchar](30) NULL,
	[City] [nvarchar](20) NULL,
	[State] [nvarchar](15) NULL,
	[Zip_Code] [nvarchar](15) NULL,
	[Phone_1] [nvarchar](20) NULL,
	[EMail] [nvarchar](50) NULL,
	[Birthday] [datetime] NULL,
	[Picture] [nvarchar](125) NULL,
	[CFA_BUYBACKS_TRADES] [nvarchar](1) NULL,
	[CFA_CC_Force] [nvarchar](1) NULL,
	[CFA_CC_Below_Floor] [nvarchar](1) NULL,
	[Current_Cash] [money] NULL,
	[CFA_Cash_Alerts] [nvarchar](1) NULL,
	[CFA_Cash_Pickup] [nvarchar](1) NULL,
	[CDL_Stations_ID] [nvarchar](5) NULL,
	[CFA_Issue_Credit_Slip] [nvarchar](1) NULL,
	[CFA_Redeem_Credit_Slip] [nvarchar](1) NULL,
	[CFA_REFUND_OVERRIDE] [nvarchar](1) NULL,
	[CFA_DRAWER_TRANSFER] [nvarchar](1) NULL,
	[CFA_LARGE_PURCHASES] [nvarchar](1) NULL,
	[CFA_AUCTION_PHOTO] [nvarchar](1) NULL,
	[CFA_AUCTION_LISTREDEEM] [nvarchar](1) NULL,
	[CFA_AUCTION_SHIP] [nvarchar](1) NULL,
	[CFA_APPROVE_CASHCOUNT] [nvarchar](1) NULL,
	[Orig_Emp_ID] [nvarchar](10) NULL,
	[Orig_Store_ID] [nvarchar](10) NULL,
	[CD_Name] [nvarchar](25) NULL,
	[CFA_APPROVE_OLD_RETURNS] [nvarchar](1) NULL,
	[CFA_APPROVE_EMERGENCY_CLOCKOUT] [nvarchar](1) NULL,
	[TimeWorkedThisPeriod] [float] NULL,
	[OvertimeThreshold] [smallint] NULL,
	[CFA_PULLBACK_INVOICE] [nvarchar](1) NULL,
	[CFA_MANAGE_TIMECLOCK] [nvarchar](1) NULL,
	[CFA_PERFORM_ENDOFDAY] [nvarchar](1) NULL,
	[CFA_HOST_LOGIN] [nvarchar](1) NULL,
	[CFA_REST_OPENTABS] [nvarchar](1) NULL,
	[CFA_REST_TAKEOUT] [nvarchar](1) NULL,
	[CFA_REST_DELIVERY] [nvarchar](1) NULL,
	[CFA_INVOICE_DELETESENT] [nvarchar](1) NULL,
	[CFA_INVEN_VIEW] [nvarchar](1) NULL,
	[CFA_INVEN_VIEWCOST] [nvarchar](1) NULL,
	[CFA_INVEN_NEGATIVE_INSTANTPOS] [nvarchar](1) NULL,
	[CFA_ENDTRANS_CASH] [nvarchar](1) NULL,
	[CFA_ENDTRANS_ACCOUNT] [nvarchar](1) NULL,
	[CFA_REST_COMP] [nvarchar](1) NULL,
	[CFA_CH_FORCE] [nvarchar](1) NULL,
	[CFA_TS_CONFIG] [nvarchar](1) NULL,
	[CFA_TRANSFER_SERVER] [nvarchar](1) NULL,
	[CFA_BACKUP_DATABASE] [nvarchar](1) NULL,
	[CFA_CREDIT_CARD_SETTLEMENT] [nvarchar](1) NULL,
	[CFA_KITCHEN_REPRINT] [nvarchar](1) NULL,
	[CFA_SETUP_RECEIPT_NOTES] [nvarchar](1) NULL,
	[CFA_MANAGE_TIMECLOCK_OWNTIME] [nvarchar](1) NULL,
	[CFA_SETUP_ADD_EMPLOYEES] [nvarchar](1) NULL,
	[CFA_SETUP_EDIT_EMPLOYEES] [nvarchar](1) NULL,
	[CFA_INVENTORY_PROMOTIONS] [nvarchar](1) NULL,
	[CFA_INVOICE_DISCOUNTS_BELOW_X] [nvarchar](1) NULL,
	[CFA_BUYBACKTRADE_ABOVE_SET_AMOUNT] [nvarchar](1) NULL,
	[CFA_REPORTS_VIEW_HISTORICAL_DATA] [nvarchar](1) NULL,
	[CFA_INVEN_MISC_FIELD_LOCKDOWN] [nvarchar](1) NULL,
	[CFA_HH_Create_PO] [nvarchar](1) NULL,
	[CFA_HH_DSD] [nvarchar](1) NULL,
	[CFA_HH_DSD_Credit] [nvarchar](1) NULL,
	[CFA_HH_PO_Receive] [nvarchar](1) NULL,
	[CFA_HH_Inv_Edit] [nvarchar](1) NULL,
	[CFA_HH_Inv_Adjust] [nvarchar](1) NULL,
	[CFA_HH_Inv_Count] [nvarchar](1) NULL,
	[CFA_HH_Setup] [nvarchar](1) NULL,
	[CFA_CASHIER_OVERRIDE_LICENSESCAN] [nvarchar](1) NULL,
	[CFA_INVEN_DELETE] [nvarchar](1) NULL,
	[CFA_CASHIER_MANUALY_ENTER_AGE] [nvarchar](1) NULL,
	[CreateDate] [datetime] NULL,
	[DateDisabled] [datetime] NULL,
	[CFA_INVEN_ADD_COUPON] [nvarchar](1) NULL,
	[CFA_INVEN_GLOBALPRICING] [nvarchar](1) NULL,
	[CFA_EMP_SCHEDULE_OVERRIDE] [nvarchar](1) NULL,
	[CFA_LABOR_SCHEDULER] [nvarchar](1) NULL,
	[GLNumber] [nvarchar](70) NULL,
	[CFA_NEGATIVE_PRICE_CHANGE] [nvarchar](1) NULL,
	[CFA_CUSTOMER_EDIT_CHARGEATCOST] [nvarchar](1) NULL,
	[CFA_GPI_FUEL_DRIVE_OFF] [nvarchar](1) NULL,
	[CFA_SETUP_VPDCONFIGURATION] [nvarchar](1) NULL,
	[CFA_CLOSE_SHIFT] [nvarchar](1) NULL,
	[CFA_REPRINT_RECEIPT] [nvarchar](1) NULL,
	[Locked_Time] [datetime] NULL,
	[Retry_Count] [int] NULL,
	[Password_Hash] [nvarchar](500) NULL,
	[Salt_Key] [nvarchar](500) NULL,
	[EnableMobileInventory] [bit] NOT NULL,
	[CFA_INVOICE_LIMIT_ITEMS] [nvarchar](1) NULL,
	[CFA_HH_SHARE_PURCHASEORDERS] [nvarchar](1) NULL,
	[CFA_HH_ADD_ITEM] [nvarchar](1) NULL,
	[CFA_HH_VIEW_COST] [nvarchar](1) NULL,
	[CFA_HH_PRINT_LABELS] [nvarchar](1) NULL,
	[CFA_DELETE_CUSTOMER] [nvarchar](1) NULL,
	[CFA_RECALL_INVOICE] [nvarchar](1) NULL,
 CONSTRAINT [pkEmployee] PRIMARY KEY CLUSTERED 
(
	[Cashier_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Employee_Accounting_Transaction]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Employee_Accounting_Transaction](
	[EmpId] [nvarchar](10) NOT NULL,
	[EditSequence] [nvarchar](20) NULL,
 CONSTRAINT [pkEmployee_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[EmpId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Employee_AdditionalInfo]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Employee_AdditionalInfo](
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[FederalAllowances] [int] NULL,
	[AdditionalFederalWithholdingAmount] [money] NULL,
	[StateAllowances] [int] NULL,
	[AdditionalStateWithholdingAmount] [money] NULL,
	[StateAdditionalCredits] [int] NULL,
	[Exempt] [bit] NULL,
	[TaxFilingStatus] [bit] NULL,
	[ExcludeInPayrollExp] [bit] NOT NULL,
	[payroll_employee_number] [nvarchar](20) NULL,
	[division] [nvarchar](20) NULL,
 CONSTRAINT [pkEmployee_AdditionalInfo] PRIMARY KEY CLUSTERED 
(
	[Cashier_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Employee_JobCode]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Employee_JobCode](
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[JobCodeID] [nvarchar](15) NOT NULL,
	[Hourly_Wage] [money] NULL,
	[OvertimeHourly_Wage] [money] NULL,
 CONSTRAINT [pkEmployee_JobCode] PRIMARY KEY CLUSTERED 
(
	[Cashier_ID] ASC,
	[JobCodeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Employee_Password_History]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Employee_Password_History](
	[Cashier_Id] [nvarchar](10) NOT NULL,
	[Password] [nvarchar](500) NULL,
	[Salt_Key] [nvarchar](500) NULL,
	[CreationDate] [datetime] NOT NULL,
 CONSTRAINT [pk_Employee_Password_History] PRIMARY KEY CLUSTERED 
(
	[Cashier_Id] ASC,
	[CreationDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Employee_PermExceptions]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Employee_PermExceptions](
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[CFA_Setup_Company] [smallint] NULL,
	[CFA_Setup_Tax] [smallint] NULL,
	[CFA_Setup_Bonus] [smallint] NULL,
	[CFA_Setup_Accounting] [smallint] NULL,
	[CFA_Setup_Discounts] [smallint] NULL,
	[CFA_Setup_Display] [smallint] NULL,
	[CFA_Setup_DefPrinter] [smallint] NULL,
	[CFA_Inven_Add] [smallint] NULL,
	[CFA_Inven_Edit] [smallint] NULL,
	[CFA_Vendors_Add] [smallint] NULL,
	[CFA_Vendors_Edit] [smallint] NULL,
	[CFA_Depts_Add] [smallint] NULL,
	[CFA_Depts_Edit] [smallint] NULL,
	[CFA_Inven_TickVouch] [smallint] NULL,
	[CFA_Cust_Add] [smallint] NULL,
	[CFA_Cust_Edit] [smallint] NULL,
	[CFA_Reports_Display] [smallint] NULL,
	[CFA_Reports_DDR] [smallint] NULL,
	[CFA_Reports_Print] [smallint] NULL,
	[CFA_Invoice_Discount] [smallint] NULL,
	[CFA_Invoice_PriceChange] [smallint] NULL,
	[CFA_Invoice_DeleteItems] [smallint] NULL,
	[CFA_Invoice_Void] [smallint] NULL,
	[CFA_CRE_Acct] [smallint] NULL,
	[CFA_CRE_Exit] [smallint] NULL,
	[CFA_Display_Balance] [smallint] NULL,
	[CFA_Refund_Item] [smallint] NULL,
	[CFA_Receive_Items] [smallint] NULL,
	[CFA_DO_POS] [smallint] NULL,
	[CFA_INSTANT_POS] [smallint] NULL,
	[CFA_OTHER_TABLES] [smallint] NULL,
	[CFA_ACCEPT_CASH] [smallint] NULL,
	[CFA_TRANSFER_NOSWIPE] [smallint] NULL,
	[CFA_ADD_CCTIPS] [smallint] NULL,
	[CFA_PRINT_HOLD] [smallint] NULL,
	[CFA_OPEN_CASH_DRAWER] [smallint] NULL,
	[CFA_TRANSFER_TABLES] [smallint] NULL,
	[CFA_SPLIT_CHECKS] [smallint] NULL,
	[CFA_EXTRA_ITEM] [smallint] NULL,
	[CFA_TAX_EXEMPT] [smallint] NULL,
	[CFA_GC_Sell] [smallint] NULL,
	[CFA_GC_Redeem] [smallint] NULL,
	[CFA_SELL_SPECIAL_ITEM] [smallint] NULL,
	[CFA_VENDOR_PAYOUT] [smallint] NULL,
	[CFA_APPLY_GRATUITY] [smallint] NULL,
	[CFA_BUYBACKS_TRADES] [smallint] NULL,
	[CFA_CC_Force] [smallint] NULL,
	[CFA_CC_BELOW_FLOOR] [smallint] NULL,
	[CFA_CASH_ALERTS] [smallint] NULL,
	[CFA_CASH_PICKUP] [smallint] NULL,
	[CFA_ISSUE_CREDIT_SLIP] [smallint] NULL,
	[CFA_REDEEM_CREDIT_SLIP] [smallint] NULL,
	[CFA_REFUND_OVERRIDE] [smallint] NULL,
	[CFA_DRAWER_TRANSFER] [smallint] NULL,
	[CFA_LARGE_PURCHASES] [smallint] NULL,
	[CFA_AUCTION_PHOTO] [smallint] NULL,
	[CFA_AUCTION_LISTREDEEM] [smallint] NULL,
	[CFA_AUCTION_SHIP] [smallint] NULL,
	[CFA_APPROVE_CASHCOUNT] [smallint] NULL,
	[CFA_APPROVE_OLD_RETURNS] [smallint] NULL,
	[CFA_APPROVE_EMERGENCY_CLOCKOUT] [smallint] NULL,
	[CFA_PULLBACK_INVOICE] [smallint] NULL,
	[CFA_MANAGE_TIMECLOCK] [smallint] NULL,
	[CFA_PERFORM_ENDOFDAY] [smallint] NULL,
	[CFA_HOST_LOGIN] [smallint] NULL,
	[CFA_REST_OPENTABS] [int] NULL,
	[CFA_REST_TAKEOUT] [int] NULL,
	[CFA_REST_DELIVERY] [int] NULL,
	[CFA_INVOICE_DELETESENT] [int] NULL,
	[CFA_INVEN_VIEW] [int] NULL,
	[CFA_INVEN_VIEWCOST] [int] NULL,
	[CFA_INVEN_NEGATIVE_INSTANTPOS] [int] NULL,
	[CFA_ENDTRANS_CASH] [int] NULL,
	[CFA_ENDTRANS_ACCOUNT] [int] NULL,
	[CFA_REST_COMP] [int] NULL,
	[CFA_CH_FORCE] [int] NULL,
	[CFA_TS_CONFIG] [int] NULL,
	[CFA_TRANSFER_SERVER] [int] NULL,
	[CFA_BACKUP_DATABASE] [int] NULL,
	[CFA_CREDIT_CARD_SETTLEMENT] [int] NULL,
	[CFA_KITCHEN_REPRINT] [int] NULL,
	[CFA_SETUP_RECEIPT_NOTES] [int] NULL,
	[CFA_MANAGE_TIMECLOCK_OWNTIME] [int] NULL,
	[CFA_SETUP_ADD_EMPLOYEES] [int] NULL,
	[CFA_SETUP_EDIT_EMPLOYEES] [int] NULL,
	[CFA_INVENTORY_PROMOTIONS] [int] NULL,
	[CFA_INVOICE_DISCOUNTS_BELOW_X] [int] NULL,
	[CFA_BUYBACKTRADE_ABOVE_SET_AMOUNT] [int] NULL,
	[CFA_REPORTS_VIEW_HISTORICAL_DATA] [int] NULL,
	[CFA_INVEN_MISC_FIELD_LOCKDOWN] [int] NULL,
	[CFA_HH_Create_PO] [int] NULL,
	[CFA_HH_DSD] [int] NULL,
	[CFA_HH_DSD_Credit] [int] NULL,
	[CFA_HH_PO_Receive] [int] NULL,
	[CFA_HH_Inv_Edit] [int] NULL,
	[CFA_HH_Inv_Adjust] [int] NULL,
	[CFA_HH_Inv_Count] [int] NULL,
	[CFA_HH_Setup] [int] NULL,
	[CFA_CASHIER_OVERRIDE_LICENSESCAN] [int] NULL,
	[CFA_INVEN_DELETE] [int] NULL,
	[CFA_CASHIER_MANUALY_ENTER_AGE] [int] NULL,
	[CFA_INVEN_ADD_COUPON] [int] NULL,
	[CFA_INVEN_GLOBALPRICING] [int] NULL,
	[CFA_EMP_SCHEDULE_OVERRIDE] [int] NULL,
	[CFA_LABOR_SCHEDULER] [int] NULL,
	[CFA_NEGATIVE_PRICE_CHANGE] [int] NULL,
	[CFA_CUSTOMER_EDIT_CHARGEATCOST] [int] NULL,
	[CFA_DELETE_CUSTOMER] [int] NULL,
	[CFA_RECALL_INVOICE] [int] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EmployeePermissions]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmployeePermissions](
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[PermissionID] [int] NOT NULL,
	[AccessLevel] [int] NULL,
	[Exception] [bit] NULL,
 CONSTRAINT [pkEmployeePermissions] PRIMARY KEY CLUSTERED 
(
	[Cashier_ID] ASC,
	[PermissionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EmployeeStores]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmployeeStores](
	[RowID] [uniqueidentifier] NOT NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[Store_ID] [nvarchar](10) NULL,
	[Inactive] [bit] NOT NULL,
 CONSTRAINT [pkEmployeeStores] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Encryption_Key_History]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Encryption_Key_History](
	[Store_Id] [nvarchar](10) NOT NULL,
	[Password] [nvarchar](500) NULL,
	[Salt_Key] [nvarchar](500) NULL,
	[CreationDate] [datetime] NOT NULL,
 CONSTRAINT [pk_Encryption_Key_History] PRIMARY KEY CLUSTERED 
(
	[Store_Id] ASC,
	[CreationDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EndOfDayCustomTotals]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EndOfDayCustomTotals](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Close_Out_Index] [int] NOT NULL,
	[Description] [nvarchar](30) NOT NULL,
	[Amount] [money] NULL,
 CONSTRAINT [pkEndOfDayCustomTotals] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Close_Out_Index] ASC,
	[Description] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EndOfDayCustomTotalsSetup]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EndOfDayCustomTotalsSetup](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Description] [nvarchar](30) NOT NULL,
	[GLNumber] [nvarchar](20) NULL,
	[GLNumberOffset] [nvarchar](20) NULL,
	[Enabled] [bit] NULL,
 CONSTRAINT [pkEndOfDayCustomTotalsSetup] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Description] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Exceptions]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Exceptions](
	[ID] [bigint] NOT NULL,
	[Exception_DateTime] [datetime] NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[Override_Cashier_ID] [nvarchar](10) NULL,
	[Exception_Type] [smallint] NULL,
	[Reason_Code] [nvarchar](100) NULL,
	[RowID] [nvarchar](40) NOT NULL,
 CONSTRAINT [pkExceptions] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Exchange_AdditionalInfo]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Exchange_AdditionalInfo](
	[ID] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NULL,
	[Invoice_Number] [bigint] NULL,
	[WebOrderNumber] [nvarchar](20) NULL,
	[CREOrderStatus] [int] NULL,
	[Comment] [nvarchar](255) NULL,
	[ShippingCarrierName] [nvarchar](100) NULL,
	[ShippingTrackingNumber] [nvarchar](255) NULL,
 CONSTRAINT [pkExchange_AdditionalInfo] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Finance_Charges]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Finance_Charges](
	[ID] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Custnum] [nvarchar](12) NULL,
	[Finance_Charge_Type] [int] NULL,
	[Finance_Charge_Date] [datetime] NULL,
	[Percentage_Applied] [real] NULL,
	[Amount] [money] NULL,
	[Invoice_Number] [bigint] NULL,
	[Cashier_ID] [nvarchar](10) NULL,
 CONSTRAINT [pkFinance_Charges] PRIMARY KEY CLUSTERED 
(
	[ID] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Friendly_Printers]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Friendly_Printers](
	[Store_ID] [nvarchar](10) NOT NULL,
	[PrinterName] [nvarchar](30) NOT NULL,
 CONSTRAINT [pkFriendly_Printers] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PrinterName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[GeneralLog]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GeneralLog](
	[RowID] [uniqueidentifier] NOT NULL,
	[Creation_Date] [datetime] NULL,
	[Store_ID] [nvarchar](10) NULL,
	[Station_ID] [nvarchar](10) NULL,
	[LogType] [int] NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[Description] [nvarchar](max) NULL,
 CONSTRAINT [pkGeneralLog] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Groups]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Groups](
	[Group_ID] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Description] [nvarchar](20) NULL,
	[ItemNumPrefix] [nvarchar](10) NULL,
	[Cost] [money] NULL,
	[Price] [money] NULL,
	[Tax_1] [bit] NOT NULL,
	[Tax_2] [bit] NOT NULL,
	[Tax_3] [bit] NOT NULL,
	[Dim_1_Name] [nvarchar](15) NULL,
	[Dim_2_Name] [nvarchar](15) NULL,
	[Dept_ID] [nvarchar](8) NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[AutoGenerate] [bit] NOT NULL,
	[isDeleted] [bit] NOT NULL,
	[Tax_4] [bit] NULL,
	[Tax_5] [bit] NULL,
	[Tax_6] [bit] NULL,
 CONSTRAINT [pkGroups] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Group_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Groups_Dimensions]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Groups_Dimensions](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Group_ID] [nvarchar](20) NOT NULL,
	[Dimension] [nvarchar](15) NOT NULL,
	[IndexPos] [int] NULL,
	[XY] [nvarchar](1) NOT NULL,
 CONSTRAINT [pkGroups_Dimensions] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Group_ID] ASC,
	[Dimension] ASC,
	[XY] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Groups_Reference]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Groups_Reference](
	[ID] [int] NULL,
	[Group_ID] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkGroups_Reference] PRIMARY KEY CLUSTERED 
(
	[Group_ID] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Ingredients_Used]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Ingredients_Used](
	[ID] [int] NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Reason] [nvarchar](1) NULL,
	[Date_Used] [datetime] NULL,
 CONSTRAINT [pkIngredients_Used] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Accounting_Transaction]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Accounting_Transaction](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Id] [nvarchar](38) NOT NULL,
	[Txn_Id] [nvarchar](20) NOT NULL,
	[EditSequence] [nvarchar](15) NULL,
 CONSTRAINT [pkInventory_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Id] ASC,
	[Txn_Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_AdditionalInfo]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_AdditionalInfo](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[ExtendedDescription] [nvarchar](max) NULL,
	[Keywords] [nvarchar](300) NULL,
	[Brand] [nvarchar](50) NULL,
	[Theme] [nvarchar](50) NULL,
	[SubCategory] [nvarchar](50) NULL,
	[LeadTime] [nvarchar](100) NULL,
	[ProductOnPromotionPreOrder] [bit] NULL,
	[ProductOnSpecialOffer] [bit] NULL,
	[NewProduct] [bit] NULL,
	[Discountable] [bit] NULL,
	[WebPrice] [money] NULL,
	[ReleaseDate] [datetime] NULL,
	[Weight] [float] NULL,
	[NoWebSales] [bit] NOT NULL,
	[IsPrimaryMatrixItem] [bit] NOT NULL,
	[Priority] [tinyint] NOT NULL,
	[Rating] [tinyint] NOT NULL,
	[CustomNumber1] [smallint] NOT NULL,
	[CustomNumber2] [smallint] NOT NULL,
	[CustomNumber3] [smallint] NOT NULL,
	[CustomNumber4] [smallint] NOT NULL,
	[CustomNumber5] [smallint] NOT NULL,
	[CustomText1] [nvarchar](250) NOT NULL,
	[CustomText2] [nvarchar](250) NOT NULL,
	[CustomText3] [nvarchar](250) NOT NULL,
	[CustomText4] [nvarchar](250) NOT NULL,
	[CustomText5] [nvarchar](250) NOT NULL,
	[CustomExtendedText1] [nvarchar](max) NOT NULL,
	[CustomExtendedText2] [nvarchar](max) NOT NULL,
	[SubDescription1] [nvarchar](70) NOT NULL,
	[SubDescription2] [nvarchar](70) NOT NULL,
	[SubDescription3] [nvarchar](70) NOT NULL,
 CONSTRAINT [pkInventory_AdditionalInfo] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Bulk_Info]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Bulk_Info](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Bulk_Price] [decimal](25, 8) NOT NULL,
	[Bulk_Quan] [decimal](25, 8) NOT NULL,
	[Description] [nvarchar](30) NULL,
	[Price_Type] [int] NULL,
 CONSTRAINT [pkInventory_Bulk_Info] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Bulk_Quan] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_BumpBarSettings]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_BumpBarSettings](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Backcolor] [int] NULL,
	[Forecolor] [int] NULL,
 CONSTRAINT [pkInventory_BumpBarSettings] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Commissions]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Commissions](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Comm_Type] [int] NULL,
	[Comm_Amt] [decimal](25, 8) NULL,
 CONSTRAINT [pkInventory_Commissions] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Consignment]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Consignment](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[CustNum] [nvarchar](12) NOT NULL,
	[Auction_Type] [int] NULL,
	[Description] [ntext] NULL,
	[Notes] [ntext] NULL,
	[Status] [int] NULL,
	[Pics] [ntext] NULL,
	[Auction_Duration] [int] NULL,
	[Auction_Start] [datetime] NULL,
	[Auction_End] [datetime] NULL,
	[Opening_Bid] [money] NULL,
	[BuyItNow] [money] NULL,
	[Selling_Price] [money] NULL,
	[Buyer] [nvarchar](12) NULL,
	[Handling_Fee] [money] NULL,
	[Weight] [float] NULL,
	[Manufacturer] [nvarchar](50) NULL,
	[Condition] [nvarchar](20) NULL,
	[Missing_Parts] [bit] NOT NULL,
	[Missing_Parts_Itemized] [nvarchar](255) NULL,
	[Item_Age] [nvarchar](20) NULL,
	[Auction_ID] [nvarchar](100) NULL,
	[Fees] [money] NULL,
	[Tracking_Num] [nvarchar](50) NULL,
	[Ship_Method] [nvarchar](15) NULL,
	[Buyer_Email] [nvarchar](50) NULL,
	[Previously_Listed] [smallint] NULL,
	[Buyer_Name] [nvarchar](50) NULL,
	[Paid_Online] [bit] NULL,
	[Payment_DateTime] [datetime] NULL,
	[Payment_Method] [nvarchar](20) NULL,
	[Check_Sent] [bit] NULL,
	[Check_Sent_DateTime] [datetime] NULL,
 CONSTRAINT [pkInventory_Consignment] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_CostDisc]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_CostDisc](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Desc1] [nvarchar](15) NULL,
	[Amt1] [decimal](25, 8) NOT NULL,
	[Type1] [int] NULL,
	[Desc2] [nvarchar](15) NULL,
	[Amt2] [decimal](25, 8) NOT NULL,
	[Type2] [int] NULL,
	[Desc3] [nvarchar](15) NULL,
	[Amt3] [decimal](25, 8) NOT NULL,
	[Type3] [int] NULL,
 CONSTRAINT [pkInventory_CostDisc] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Coupon]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Coupon](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Exp_Date] [datetime] NULL,
	[Enforce_Exp] [bit] NOT NULL,
	[Include_All_Except] [bit] NOT NULL,
	[Coupon_Flat_Percent] [smallint] NULL,
	[Coupon_Bonus_Only] [bit] NOT NULL,
	[Apply_To_Parent] [bit] NOT NULL,
	[Suppress_Bonus] [bit] NOT NULL,
	[Minimum_Amount_Restriction] [money] NULL,
	[NumDays_Restriction] [smallint] NULL,
	[ApplyOnDiscountedItems] [bit] NULL,
	[ApplyOnSpecialPricing] [bit] NULL,
	[Coupon_Bonus_MinimumQuantity] [decimal](25, 8) NOT NULL,
 CONSTRAINT [pkInventory_Coupon] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Coupon_Rules]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Coupon_Rules](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Type] [int] NOT NULL,
	[ID] [nvarchar](20) NOT NULL,
	[Allow_Or_Disallow] [int] NULL,
 CONSTRAINT [pkInventory_Coupon_Rules] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[ID] ASC,
	[Type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_CustPrices]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_CustPrices](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[CustNum] [nvarchar](12) NOT NULL,
	[Price] [decimal](25, 8) NULL,
	[Allow_Discounts] [bit] NOT NULL,
 CONSTRAINT [pkInventory_CustPrices] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_DiscLevels]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_DiscLevels](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Level] [nvarchar](2) NOT NULL,
	[Perc] [real] NULL,
 CONSTRAINT [pkInventory_DiscLevels] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Level] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_GasPumpInterface]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_GasPumpInterface](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[FuelDepartment] [nvarchar](4) NOT NULL,
	[FuelType] [nvarchar](20) NULL,
 CONSTRAINT [pkInventory_GasPumpInterface] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[FuelDepartment] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Image]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Image](
	[ID] [bigint] NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Position] [int] NULL,
	[ImageLocation] [nvarchar](4000) NOT NULL,
 CONSTRAINT [pkInventory_Image] PRIMARY KEY CLUSTERED 
(
	[ItemNum] ASC,
	[Store_ID] ASC,
	[ImageLocation] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_In]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_In](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Quantity] [decimal](25, 8) NOT NULL,
	[CostPer] [decimal](25, 8) NOT NULL,
	[DateTime] [datetime] NOT NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Dirty] [bit] NOT NULL,
	[TransType] [nvarchar](2) NULL,
	[Destination] [nvarchar](10) NULL,
	[Description] [nvarchar](30) NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[PO_Number] [int] NULL,
	[Delivery_Number] [nvarchar](20) NULL,
	[RowID] [nvarchar](38) NOT NULL,
 CONSTRAINT [pkInventory_In] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Ingredients]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Ingredients](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Ingredient] [nvarchar](20) NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Measurement] [int] NULL,
	[Yield] [real] NULL,
 CONSTRAINT [pkInventory_Ingredients] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Ingredient] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_KitComboSpecific]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_KitComboSpecific](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[ComboPricingCalculation] [int] NULL,
 CONSTRAINT [pkInventory_KitComboSpecific] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Matrix_Info]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Matrix_Info](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Group_ID] [nvarchar](20) NOT NULL,
	[Dim_1] [nvarchar](10) NULL,
	[Dim_2] [nvarchar](10) NULL,
 CONSTRAINT [pkInventory_Matrix_Info] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Matrix_Info_Reference]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Matrix_Info_Reference](
	[ID] [int] NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Group_ID] [nvarchar](20) NULL,
 CONSTRAINT [pkInventory_Matrix_Info_Reference] PRIMARY KEY CLUSTERED 
(
	[ItemNum] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_MixNMatch_Levels]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_MixNMatch_Levels](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Amount] [float] NULL,
	[Quantity] [decimal](25, 8) NOT NULL,
 CONSTRAINT [pkInventory_MixNMatch_Levels] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Quantity] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Notes]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Notes](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Notes] [ntext] NULL,
 CONSTRAINT [pkInventory_Notes] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_OnSale_Info]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_OnSale_Info](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Sale_Start] [datetime] NOT NULL,
	[Sale_End] [datetime] NOT NULL,
	[Percent] [float] NOT NULL,
	[Price] [decimal](25, 8) NULL,
	[SalePriceType] [int] NULL,
 CONSTRAINT [pkInventory_OnSale_Info] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Sale_Start] ASC,
	[Sale_End] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_PendingOrders]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_PendingOrders](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[DueDate] [datetime] NULL,
	[PickupType] [smallint] NULL,
	[Status] [smallint] NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[LineNum] [smallint] NOT NULL,
 CONSTRAINT [pkInventory_PendingOrders] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Invoice_Number] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Prices]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Prices](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Price] [decimal](25, 8) NULL,
	[Criteria1] [nvarchar](30) NOT NULL,
	[Criteria2] [nvarchar](30) NOT NULL,
	[Criteria3] [nvarchar](30) NOT NULL,
	[Enabled] [bit] NOT NULL,
	[PriceType] [int] NOT NULL,
 CONSTRAINT [pkInventory_Prices] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Criteria1] ASC,
	[Criteria2] ASC,
	[Criteria3] ASC,
	[PriceType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Properties]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Properties](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Value_ID] [smallint] NOT NULL,
	[StoreWithInvoice] [bit] NULL,
 CONSTRAINT [pkInventory_Properties] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Value_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Reference]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Reference](
	[ID] [int] NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkInventory_Reference] PRIMARY KEY CLUSTERED 
(
	[ItemNum] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Remote]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Remote](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[In_Stock] [float] NULL,
 CONSTRAINT [pkInventory_Remote] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Rental_Info]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Rental_Info](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Late_Charge] [money] NOT NULL,
	[Days_Rent] [int] NOT NULL,
	[Due_Date] [datetime] NULL,
	[Status] [nvarchar](10) NULL,
	[CurrCust] [nvarchar](12) NULL,
	[LastCust] [nvarchar](12) NULL,
	[NumRentals] [int] NOT NULL,
	[Rating] [nvarchar](10) NULL,
	[Actor_Last_Name] [nvarchar](15) NULL,
	[Actress_Last_Name] [nvarchar](15) NULL,
	[Inv_Approval_Code] [nvarchar](15) NULL,
	[Primary] [bit] NOT NULL,
	[RowID] [nvarchar](38) NOT NULL,
	[Invoice_Number] [bigint] NULL,
 CONSTRAINT [pkInventory_Rental_Info] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Reorder]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Reorder](
	[ItemNum] [nvarchar](20) NOT NULL,
	[ItemName] [nvarchar](30) NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cost] [decimal](25, 8) NULL,
	[In_Stock] [decimal](25, 8) NULL,
	[Reorder_Level] [float] NULL,
	[Reorder_Quantity] [float] NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Dept_ID] [nvarchar](8) NULL,
 CONSTRAINT [pkInventory_Reorder] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Serial_Incoming]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Serial_Incoming](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[SerialNum] [nvarchar](20) NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Date_Received] [datetime] NULL,
	[PO_Number] [int] NULL,
 CONSTRAINT [pkInventory_Serial_Incoming] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[SerialNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_SKUS]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_SKUS](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[AltSKU] [nvarchar](30) NOT NULL,
 CONSTRAINT [pkInventory_SKUS] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[AltSKU] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Special]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Special](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Serial] [nvarchar](12) NOT NULL,
	[CustNum] [nvarchar](30) NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Price] [decimal](25, 8) NULL,
	[DateTime] [datetime] NULL,
 CONSTRAINT [pkInventory_Special] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Serial] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_TagAlongs]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_TagAlongs](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[TagAlong_ItemNum] [nvarchar](20) NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
 CONSTRAINT [pkInventory_TagAlongs] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[TagAlong_ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Taking]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Taking](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemName] [nvarchar](30) NULL,
	[In_Stock] [decimal](25, 8) NULL,
	[Price] [decimal](25, 8) NULL,
	[Cost] [decimal](25, 8) NULL,
	[EditType] [int] NULL,
	[Counted] [bit] NOT NULL,
	[Location] [nvarchar](30) NULL,
	[Vendor_Part_Num] [nvarchar](20) NULL,
	[RowID] [nvarchar](40) NOT NULL,
	[Reason] [nvarchar](30) NULL,
	[Cashier_ID] [nvarchar](10) NULL,
 CONSTRAINT [pkInventory_Taking] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Transfers_In]    Script Date: 1/30/2026 5:30:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Transfers_In](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
	[CostPer] [decimal](25, 8) NULL,
	[DateTime] [datetime] NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Dirty] [bit] NOT NULL,
	[TransType] [nvarchar](2) NULL,
	[Originator] [nvarchar](10) NULL,
	[Description] [nvarchar](30) NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[PO_Number] [int] NULL,
	[Delivery_Number] [nvarchar](20) NULL,
	[Trans_ID] [nvarchar](40) NOT NULL,
	[Description2] [nvarchar](30) NULL,
 CONSTRAINT [pkInventory_Transfers_In] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Trans_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Transfers_Out]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Transfers_Out](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
	[CostPer] [decimal](25, 8) NULL,
	[DateTime] [datetime] NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Dirty] [bit] NOT NULL,
	[TransType] [nvarchar](2) NULL,
	[Destination] [nvarchar](10) NULL,
	[Description] [nvarchar](30) NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[PO_Number] [int] NULL,
	[Delivery_Number] [nvarchar](20) NULL,
	[Trans_ID] [nvarchar](40) NOT NULL,
	[Description2] [nvarchar](30) NULL,
 CONSTRAINT [pkInventory_Transfers_Out] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Trans_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Transfers_Serials_In]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Transfers_Serials_In](
	[Trans_ID] [nvarchar](40) NOT NULL,
	[ItemNum] [nvarchar](20) NULL,
	[SerialNum] [nvarchar](20) NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Dirty] [bit] NULL,
	[Originator] [nvarchar](10) NULL,
 CONSTRAINT [pkInventory_Transfers_Serials_In] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Trans_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Transfers_Serials_Out]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Transfers_Serials_Out](
	[Trans_ID] [nvarchar](40) NOT NULL,
	[ItemNum] [nvarchar](20) NULL,
	[SerialNum] [nvarchar](20) NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Dirty] [bit] NULL,
	[Destination] [nvarchar](10) NULL,
 CONSTRAINT [pkInventory_Transfers_Serials_Out] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Trans_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Vendors]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Vendors](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[CostPer] [money] NULL,
	[Case_Cost] [money] NULL,
	[NumPerVenCase] [float] NULL,
	[Vendor_Part_Num] [nvarchar](20) NOT NULL,
	[CubeCost] [money] NULL,
	[WeightCost] [money] NULL,
	[OverrideCommission] [bit] NULL,
	[LandedCost] [money] NOT NULL,
 CONSTRAINT [pkInventory_Vendors] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Vendor_Number] ASC,
	[Vendor_Part_Num] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Inventory_Vendors_Copy]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventory_Vendors_Copy](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[CostPer] [money] NULL,
	[Case_Cost] [money] NULL,
	[NumPerVenCase] [float] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[InventoryOrderItems]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[InventoryOrderItems](
	[RowID] [uniqueidentifier] NOT NULL,
	[ItemNum] [nvarchar](20) NULL,
	[ItemName] [nvarchar](30) NULL,
	[Origin] [nvarchar](10) NULL,
	[Destination] [nvarchar](10) NULL,
	[QtyOrdered] [decimal](25, 8) NULL,
	[QtyReceived] [decimal](25, 8) NULL,
	[QtyDamaged] [decimal](25, 8) NULL,
	[QtyLost] [decimal](25, 8) NULL,
	[CaseOrIndividual] [nvarchar](1) NULL,
	[Status] [int] NULL,
	[OrderItemCounter] [nvarchar](32) NULL,
	[NumPerCase] [int] NULL,
	[OrderRowID] [uniqueidentifier] NULL,
 CONSTRAINT [pkInventoryOrderItems] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[InventoryOrders]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[InventoryOrders](
	[RowID] [uniqueidentifier] NOT NULL,
	[OrderID] [nvarchar](20) NULL,
	[OrderDate] [datetime] NULL,
	[OrderedBy] [nvarchar](10) NULL,
	[CreationLocation] [nvarchar](10) NULL,
	[OrderType] [int] NULL,
	[Reason] [nvarchar](20) NULL,
	[Status] [int] NULL,
	[OrderCounter] [nvarchar](21) NULL,
 CONSTRAINT [pkInventoryOrders] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[InventoryOrderSerialNumbers]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[InventoryOrderSerialNumbers](
	[RowID] [uniqueidentifier] NOT NULL,
	[ParentRowID] [nvarchar](40) NULL,
	[SerialNumber] [nvarchar](50) NULL,
 CONSTRAINT [pkInventoryOrderSerialNumbers] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_AccountingExport]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_AccountingExport](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[SubType] [bigint] NULL,
	[Txn_Id] [nvarchar](50) NOT NULL,
	[EditSequence] [nvarchar](50) NULL,
	[TaxType] [int] NULL,
	[Invoice_Type] [int] NULL,
 CONSTRAINT [pkInvoice_AccountingExport] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[Txn_Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_CouponDiscounts]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_CouponDiscounts](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[LineNum] [int] NOT NULL,
	[CouponLineNum] [int] NOT NULL,
	[Amount] [money] NULL,
 CONSTRAINT [pkInvoice_CouponDiscounts] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[LineNum] ASC,
	[CouponLineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Deliveries]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Deliveries](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Driver_ID] [nvarchar](10) NULL,
	[Time_Promised] [datetime] NULL,
 CONSTRAINT [pkInvoice_Deliveries] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Exceptions]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Exceptions](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Override_Cashier_ID] [nvarchar](10) NULL,
	[Exception_Type] [int] NULL,
	[ItemNum] [nvarchar](20) NULL,
	[Amount] [decimal](25, 8) NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Reason_Code] [nvarchar](30) NULL,
	[LineNum] [int] NOT NULL,
	[RowID] [uniqueidentifier] NOT NULL,
	[EmpName] [nvarchar](30) NULL,
	[First_Name] [nvarchar](30) NULL,
	[Last_Name] [nvarchar](30) NULL,
	[DateTime] [datetime] NULL,
 CONSTRAINT [pk_Invoice_Exceptions] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_GasPumpInterface]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_GasPumpInterface](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[LineNum] [int] NOT NULL,
	[PumpNumber] [nvarchar](2) NULL,
	[CarWashCode] [nvarchar](10) NULL,
	[Payment_Method] [nvarchar](10) NULL,
	[SaleType] [int] NULL,
	[Note1] [nvarchar](250) NULL,
	[SpecialSaleType] [int] NULL,
	[TransactionNumber] [nvarchar](10) NULL,
	[RefInvoice_Number] [bigint] NULL,
	[IsSaleComplete] [bit] NULL,
	[DollarAmount] [decimal](25, 8) NULL,
 CONSTRAINT [pkInvoice_GasPumpInterface] PRIMARY KEY CLUSTERED 
(
	[Invoice_Number] ASC,
	[Store_ID] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Itemized_ItemNotes]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Itemized_ItemNotes](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[LineNum] [int] NOT NULL,
	[Notes] [ntext] NULL,
 CONSTRAINT [pkInvoice_Itemized_ItemNotes] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Itemized_Layaway]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Itemized_Layaway](
	[Invoice_Number] [bigint] NOT NULL,
	[LineNum] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Amount_Paid] [money] NULL,
	[Picked_Up] [bit] NULL,
	[Pickup_Date] [datetime] NULL,
 CONSTRAINT [pkInvoice_Itemized_Layaway] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Itemized_Return_Details]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Itemized_Return_Details](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[LineNum] [int] NOT NULL,
	[Orig_Invoice_Number] [bigint] NOT NULL,
	[CustName] [nvarchar](31) NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Reason_Code] [nvarchar](30) NULL,
	[Dirty] [bit] NOT NULL,
	[Orig_LineNum] [int] NULL,
	[Cashier_ID] [nvarchar](10) NULL,
 CONSTRAINT [pkInvoice_Itemized_Return_Details] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Journal_Accounting_Transaction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Journal_Accounting_Transaction](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Date] [datetime] NOT NULL,
	[SubType] [int] NOT NULL,
	[CustNo] [nvarchar](12) NOT NULL,
	[Journal_Txn_Id] [nvarchar](50) NULL,
	[Journal_Edit_Seq] [nvarchar](50) NULL,
	[Debit_Txn_LineId] [nvarchar](50) NULL,
	[Credit_Txn_LineId] [nvarchar](50) NULL,
 CONSTRAINT [pkInvoice_Journal_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Date] ASC,
	[SubType] ASC,
	[CustNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_OnHold]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_OnHold](
	[Invoice_Number] [bigint] NOT NULL,
	[OnHoldID] [nvarchar](12) NOT NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Occupied] [bit] NOT NULL,
	[Section_ID] [nvarchar](15) NULL,
	[Status] [int] NULL,
	[Identifier] [nvarchar](30) NULL,
	[PreAuthorized] [bit] NULL,
	[Name] [nvarchar](12) NULL,
	[Station_ID] [nvarchar](5) NULL,
 CONSTRAINT [pkInvoice_OnHold] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Scratchboard]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Scratchboard](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[Scratchboard] [ntext] NULL,
 CONSTRAINT [pkInvoice_Scratchboard] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Serial_Sales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Serial_Sales](
	[Invoice_Number] [bigint] NOT NULL,
	[LineNum] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NULL,
	[SerialNum] [nvarchar](30) NOT NULL,
	[Price] [money] NULL,
 CONSTRAINT [pkInvoice_Serial_Sales] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[LineNum] ASC,
	[SerialNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Signatures]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Signatures](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[Signature] [ntext] NULL,
	[LineNum] [smallint] NULL,
	[Index] [int] NULL,
 CONSTRAINT [pkInvoice_Signatures] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_StateChanges]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_StateChanges](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[DateTime] [datetime] NULL,
	[State] [int] NOT NULL,
 CONSTRAINT [pkInvoice_StateChanges] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[State] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_SubCheck]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_SubCheck](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[SubCheckNum] [int] NOT NULL,
	[Paid] [bit] NOT NULL,
	[Total_Tax_1] [money] NULL,
	[Total_Tax_2] [money] NULL,
	[Total_Tax_3] [money] NULL,
	[Total_Price] [money] NULL,
	[Total_Tip] [money] NULL,
	[Total_GC_Sold] [money] NULL,
	[Grand_Total] [money] NULL,
	[SubCustNum] [nvarchar](10) NULL,
	[Total_GC_Free] [money] NULL,
	[Donation_Amount] [money] NOT NULL,
	[Total_Tax_4] [money] NULL,
	[Total_Tax_5] [money] NULL,
	[Total_Tax_6] [money] NULL,
 CONSTRAINT [pkInvoice_SubCheck] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[SubCheckNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_SubCheck_Items]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_SubCheck_Items](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[SubCheckNum] [int] NOT NULL,
	[SubCheckLineNum] [int] NOT NULL,
	[LineNum] [int] NULL,
	[Quantity] [decimal](25, 8) NULL,
	[IsModifier] [bit] NOT NULL,
 CONSTRAINT [pkInvoice_SubCheck_Items] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[SubCheckNum] ASC,
	[SubCheckLineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_SubCheck_Payments]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_SubCheck_Payments](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[SubCheckNum] [int] NOT NULL,
	[Payment_Method] [nvarchar](8) NOT NULL,
	[Amount] [money] NULL,
	[Details] [nvarchar](50) NULL,
	[InvoiceRefNum] [bigint] NOT NULL,
	[RowID] [uniqueidentifier] NOT NULL,
 CONSTRAINT [pkInvoice_SubCheck_Payments] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_SubModifiers]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_SubModifiers](
	[Invoice_Number] [bigint] NOT NULL,
	[LineNum] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[SubModifierNumber] [nvarchar](20) NOT NULL,
	[Index] [int] NOT NULL,
 CONSTRAINT [pkInvoice_SubModifiers] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[LineNum] ASC,
	[SubModifierNumber] ASC,
	[Index] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Totals_Notes]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Totals_Notes](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Line1] [nvarchar](42) NULL,
	[Line2] [nvarchar](42) NULL,
	[Line3] [nvarchar](42) NULL,
	[Line4] [nvarchar](42) NULL,
	[Line5] [nvarchar](42) NULL,
	[ExtendedNotes] [ntext] NULL,
 CONSTRAINT [pkInvoice_Totals_Notes] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Totals_Person_Mapping]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Totals_Person_Mapping](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[SeatNum] [int] NOT NULL,
 CONSTRAINT [pkInvoice_Totals_Person_Mapping] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[SeatNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Totals_Properties]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Totals_Properties](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[Name] [nvarchar](30) NOT NULL,
	[Value] [nvarchar](100) NULL,
 CONSTRAINT [pkInvoice_Totals_Properties] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Totals_ShipTos]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Totals_ShipTos](
	[Invoice_Number] [bigint] NOT NULL,
	[First_Name] [nvarchar](15) NULL,
	[Last_Name] [nvarchar](15) NULL,
	[Company] [nvarchar](30) NULL,
	[Address_1] [nvarchar](30) NULL,
	[Address_2] [nvarchar](30) NULL,
	[City] [nvarchar](20) NULL,
	[State] [nvarchar](12) NULL,
	[Zip_Code] [nvarchar](10) NULL,
	[Phone] [nvarchar](15) NULL,
	[Dirty] [bit] NOT NULL,
	[County] [nvarchar](30) NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ReferenceCustNum] [nvarchar](12) NULL,
	[Email] [nvarchar](50) NULL,
	[DeliveryAddressSpecialInstructions] [nvarchar](100) NULL,
 CONSTRAINT [pkInvoice_Totals_ShipTos] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Invoice_Totals_TaxExempt]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice_Totals_TaxExempt](
	[Invoice_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ExemptOnTheFly] [bit] NOT NULL,
	[LicenseNum] [nvarchar](20) NULL,
	[LicenseStateCode] [nvarchar](20) NULL,
	[LicenseExpDate] [datetime] NULL,
	[TaxID] [nvarchar](15) NULL,
 CONSTRAINT [pkInvoice_Totals_TaxExempt] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Item_Accounting_Transaction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Item_Accounting_Transaction](
	[ItemNum] [nvarchar](20) NOT NULL,
	[EditSequence] [nvarchar](20) NULL,
 CONSTRAINT [pkItem_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JobCode]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JobCode](
	[JobCodeID] [nvarchar](15) NOT NULL,
	[AccessToPos] [bit] NOT NULL,
	[Print_DDR] [int] NULL,
	[DDR_Num_Copies] [int] NULL,
	[Picture] [nvarchar](150) NULL,
	[Prompt_Cash_Tips] [bit] NOT NULL,
	[Record_Cash_Bank] [bit] NOT NULL,
	[Default_Wage] [money] NULL,
	[DDR_CC_Itemize] [bit] NOT NULL,
	[Require_CD_Select] [bit] NOT NULL,
	[Require_Clockout_CashBreakdown] [bit] NULL,
	[Default_OvertimeWage] [money] NULL,
	[AccessToDonationCenter] [bit] NULL,
	[AccessToProductionSoftware] [bit] NULL,
	[DeliveryTracking] [bit] NULL,
	[RoleVisibility] [int] NULL,
	[JobCodeName] [nvarchar](15) NULL,
 CONSTRAINT [pkJobCode] PRIMARY KEY CLUSTERED 
(
	[JobCodeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JobCode_Payroll_Setting]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JobCode_Payroll_Setting](
	[id] [uniqueidentifier] NOT NULL,
	[JobCodeID] [nvarchar](15) NOT NULL,
	[earning_code_name] [nvarchar](20) NOT NULL,
	[earning_code] [nvarchar](20) NULL,
	[earning_code_type] [int] NULL,
	[department_code] [nvarchar](20) NULL,
 CONSTRAINT [pk_JobCode_Payroll_Setting] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JobCode_Stores]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JobCode_Stores](
	[JobCodeID] [nvarchar](15) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkJobCode_Stores] PRIMARY KEY CLUSTERED 
(
	[JobCodeID] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JobcodePermissions]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JobcodePermissions](
	[RowID] [uniqueidentifier] NOT NULL,
	[JobCodeID] [nvarchar](15) NULL,
	[PermissionID] [int] NULL,
	[AccessLevel] [int] NULL,
	[Exception] [bit] NULL,
 CONSTRAINT [pkJobcodePermissions] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Kit_Index]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Kit_Index](
	[Kit_ID] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Discount] [real] NOT NULL,
	[Quantity] [float] NOT NULL,
	[Index] [int] NULL,
	[Price] [money] NULL,
	[Description] [nvarchar](30) NULL,
	[InvoiceMethodToUse] [int] NULL,
	[ChoiceLockdown] [int] NULL,
 CONSTRAINT [pkKit_Index] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Kit_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[LabelProduction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LabelProduction](
	[StoreID] [nvarchar](10) NULL,
	[ItemNumber] [nvarchar](20) NULL,
	[PrintDate] [datetime] NULL,
	[Quantity] [float] NULL,
	[Price] [money] NULL,
	[Reference] [nvarchar](20) NULL,
	[Reference2] [nvarchar](20) NULL,
	[RowID] [uniqueidentifier] NOT NULL,
 CONSTRAINT [pkLabelProduction] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[LogInfo]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LogInfo](
	[ID] [bigint] NOT NULL,
	[CreatedDateTime] [datetime] NULL,
	[LogEntryType] [int] NULL,
	[Source] [nvarchar](100) NULL,
	[Component] [nvarchar](100) NULL,
	[LogEntry] [nvarchar](3000) NULL,
 CONSTRAINT [pkLogInfo] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Loyalty_Card_Trans]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Loyalty_Card_Trans](
	[Trans_ID] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Card_ID] [nvarchar](50) NOT NULL,
	[DateTimeStamp] [datetime] NULL,
	[TransType] [int] NULL,
	[Invoice_Number] [bigint] NULL,
	[Dirty] [bit] NULL,
	[TotalAmt] [money] NULL,
	[Approval] [nvarchar](50) NOT NULL,
	[Reference] [nvarchar](15) NULL,
	[Price] [money] NULL,
	[Units] [int] NULL,
	[Points] [int] NULL,
	[ReceiptText] [nvarchar](1000) NULL,
 CONSTRAINT [pkLoyalty_Card_Trans] PRIMARY KEY CLUSTERED 
(
	[Trans_ID] ASC,
	[Store_ID] ASC,
	[Card_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Loyalty_Items]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Loyalty_Items](
	[Loyalty_Item_ID] [nvarchar](10) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Description] [nvarchar](30) NULL,
	[Loyalty_Type] [int] NULL,
	[Criteria] [int] NULL,
	[ItemNum] [nvarchar](20) NULL,
	[Tax_1] [bit] NOT NULL,
	[Tax_2] [bit] NOT NULL,
	[Tax_3] [bit] NOT NULL,
	[Cost] [decimal](25, 8) NULL,
	[Price] [decimal](25, 8) NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Redemption_Allowed] [bit] NOT NULL,
	[ChildItemsFree] [bit] NOT NULL,
	[Tax_4] [bit] NULL,
	[Tax_5] [bit] NULL,
	[Tax_6] [bit] NULL,
 CONSTRAINT [pkLoyalty_Items] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Loyalty_Item_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Loyalty_Items_Inclusions]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Loyalty_Items_Inclusions](
	[Loyalty_Item_ID] [nvarchar](10) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Inclusion_ID] [nvarchar](20) NOT NULL,
	[Inclusion_Type] [int] NULL,
 CONSTRAINT [pkLoyalty_Items_Inclusions] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Loyalty_Item_ID] ASC,
	[Inclusion_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Loyalty_Plans]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Loyalty_Plans](
	[Loyalty_Plan_ID] [bigint] NOT NULL,
	[Description] [nvarchar](30) NULL,
	[Accumulate_Points] [bit] NOT NULL,
 CONSTRAINT [pkLoyalty_Plans] PRIMARY KEY CLUSTERED 
(
	[Loyalty_Plan_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Loyalty_Plans_Items]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Loyalty_Plans_Items](
	[Loyalty_Plan_ID] [bigint] NOT NULL,
	[Loyalty_Item_ID] [nvarchar](10) NOT NULL,
	[Index] [smallint] NULL,
	[Exclusive] [bit] NOT NULL,
	[Prompt_Award] [bit] NOT NULL,
	[Override_Exclusive] [bit] NOT NULL,
 CONSTRAINT [pkLoyalty_Plans_Items] PRIMARY KEY CLUSTERED 
(
	[Loyalty_Plan_ID] ASC,
	[Loyalty_Item_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Loyalty_Plans_Stores]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Loyalty_Plans_Stores](
	[Loyalty_Plan_ID] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkLoyalty_Plans_Stores] PRIMARY KEY CLUSTERED 
(
	[Loyalty_Plan_ID] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Mapping_CustomerLocations]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mapping_CustomerLocations](
	[CustomerNumber] [nvarchar](12) NOT NULL,
	[Latitude] [float] NULL,
	[Longitude] [float] NULL,
 CONSTRAINT [pkMapping_CustomerLocations] PRIMARY KEY CLUSTERED 
(
	[CustomerNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Mapping_StoreLocations]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mapping_StoreLocations](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Latitude] [float] NULL,
	[Longitude] [float] NULL,
 CONSTRAINT [pkMapping_StoreLocations] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Measurements]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Measurements](
	[ID] [int] NOT NULL,
	[Description] [nvarchar](12) NULL,
 CONSTRAINT [pkMeasurements] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[metric]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[metric](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_metric] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[metric_by_day]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[metric_by_day](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[metric_id] [int] NOT NULL,
	[date_id] [int] NOT NULL,
	[value] [decimal](28, 13) NOT NULL,
	[object_id] [uniqueidentifier] NULL,
	[object_name] [nvarchar](100) NULL,
 CONSTRAINT [PK_metric_by_day] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UC_metric_by_day_metric_id_date_id_object_id] UNIQUE NONCLUSTERED 
(
	[metric_id] ASC,
	[date_id] ASC,
	[object_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[metric_by_time]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[metric_by_time](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[metric_id] [int] NOT NULL,
	[date_id] [int] NOT NULL,
	[time_id] [int] NOT NULL,
	[value] [decimal](28, 13) NOT NULL,
	[object_id] [uniqueidentifier] NULL,
	[object_name] [nvarchar](100) NULL,
 CONSTRAINT [PK_metric_by_time] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UC_metric_by_time_metric_id_date_id_time_id_object_id] UNIQUE NONCLUSTERED 
(
	[metric_id] ASC,
	[date_id] ASC,
	[time_id] ASC,
	[object_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Mobile_Discount]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mobile_Discount](
	[Store_ID] [nvarchar](10) NOT NULL,
	[DateTime] [datetime] NULL,
	[CRENumber] [bigint] NOT NULL,
	[Amount] [money] NULL,
	[TraceNumber] [nvarchar](100) NULL,
	[Sub_Invoice_Number] [int] NOT NULL,
	[CreType] [nvarchar](2) NOT NULL,
	[MobilePaymentTraceNumber] [nvarchar](100) NULL,
 CONSTRAINT [pkMobile_Discount] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[CRENumber] ASC,
	[Sub_Invoice_Number] ASC,
	[CreType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Mobile_Donations]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mobile_Donations](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Quantity] [float] NULL,
	[RefNumber] [nvarchar](20) NULL,
	[RowId] [nvarchar](40) NOT NULL,
	[Store_Id] [nvarchar](10) NOT NULL,
	[DeviceId] [nvarchar](20) NOT NULL,
	[IsChanged] [bit] NULL,
	[IsNew] [bit] NULL,
 CONSTRAINT [pkMobile_Donations] PRIMARY KEY CLUSTERED 
(
	[Store_Id] ASC,
	[ItemNum] ASC,
	[DeviceId] ASC,
	[RowId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Mobile_PO_Details]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mobile_PO_Details](
	[PO_Number] [bigint] NOT NULL,
	[Store_Id] [nvarchar](10) NOT NULL,
	[DeviceID] [nvarchar](20) NOT NULL,
	[IsChanged] [bit] NULL,
	[LineNum] [int] NOT NULL,
	[Quan_Ordered] [float] NULL,
	[CostPer] [decimal](25, 8) NULL,
	[Quan_Received] [float] NULL,
	[Vendor_Part_Number] [nvarchar](20) NULL,
	[ItemNum] [nvarchar](20) NULL,
	[destStore_ID] [nvarchar](10) NULL,
	[Current_Batch_Quan] [float] NULL,
	[Quan_Damaged] [float] NULL,
	[Quan_OutOfDate] [float] NULL,
	[CasePack] [float] NULL,
	[NumberPerCase] [float] NULL,
 CONSTRAINT [pkMobile_PO_Details] PRIMARY KEY CLUSTERED 
(
	[PO_Number] ASC,
	[Store_Id] ASC,
	[DeviceID] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Mobile_PO_Summary]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mobile_PO_Summary](
	[PO_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[DeviceId] [nvarchar](20) NOT NULL,
	[Reference] [nvarchar](15) NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Total_Cost] [decimal](25, 8) NULL,
	[Total_Cost_Received] [decimal](25, 8) NULL,
	[Terms] [nvarchar](15) NULL,
	[Due_Date] [datetime] NULL,
	[Ship_Via] [nvarchar](15) NULL,
	[ShipTo_1] [nvarchar](55) NULL,
	[ShipTo_2] [nvarchar](55) NULL,
	[ShipTo_3] [nvarchar](55) NULL,
	[ShipTo_4] [nvarchar](55) NULL,
	[ShipTo_5] [nvarchar](55) NULL,
	[Instructions] [nvarchar](95) NULL,
	[Status] [nvarchar](1) NULL,
	[Last_Modified] [datetime] NULL,
	[Dirty] [bit] NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[Billable_Department] [nvarchar](20) NULL,
	[ShipTo_Destination] [nvarchar](10) NULL,
	[Ordering_Mode] [int] NULL,
	[Fully_Authorized] [bit] NULL,
	[Print_Notes_On_PO] [bit] NULL,
	[Cancel_Date] [datetime] NULL,
	[Total_Charges] [decimal](25, 8) NULL,
	[Fully_Paid] [bit] NULL,
	[POType] [int] NULL,
	[DateTime] [datetime] NULL,
	[Distributor] [nvarchar](50) NULL,
	[Order_Reason] [nvarchar](30) NULL,
	[IsChanged] [bit] NULL,
 CONSTRAINT [pkMobile_PO_Summary] PRIMARY KEY CLUSTERED 
(
	[PO_Number] ASC,
	[Store_ID] ASC,
	[DeviceId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Mobile_Trans]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Mobile_Trans](
	[Store_ID] [nvarchar](10) NOT NULL,
	[DateTime] [datetime] NULL,
	[CRENumber] [bigint] NOT NULL,
	[Amount] [money] NULL,
	[TipAmount] [money] NULL,
	[TraceNumber] [nvarchar](100) NULL,
	[SequenceNumber] [bigint] NULL,
	[Token] [nvarchar](50) NULL,
	[Sub_Invoice_Number] [int] NOT NULL,
	[CreType] [nvarchar](2) NOT NULL,
	[TransType] [nvarchar](2) NULL,
	[CardType] [nvarchar](10) NULL,
	[ResponseMessage] [nvarchar](200) NULL,
	[QRCodeStatus] [int] NULL,
 CONSTRAINT [pkMobile_Trans] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[CRENumber] ASC,
	[Sub_Invoice_Number] ASC,
	[CreType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MobileApp_Donations]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MobileApp_Donations](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[DeviceID] [nvarchar](20) NOT NULL,
	[Quantity] [float] NULL,
	[RefNumber] [nvarchar](20) NULL,
	[RowID] [nvarchar](40) NOT NULL,
	[IsChanged] [bit] NULL,
	[IsNew] [bit] NULL,
 CONSTRAINT [pkMobileApp_Donations] PRIMARY KEY CLUSTERED 
(
	[ItemNum] ASC,
	[Store_ID] ASC,
	[DeviceID] ASC,
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MobileApp_Inventory]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MobileApp_Inventory](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemName] [nvarchar](30) NULL,
	[Dept_ID] [nvarchar](8) NULL,
	[Cost] [decimal](25, 8) NULL,
	[Price] [decimal](25, 8) NULL,
	[Retail_Price] [decimal](25, 8) NULL,
	[In_Stock] [decimal](25, 8) NULL,
	[ItemType] [int] NULL,
	[Vendor_Part_Num] [nvarchar](20) NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Inv_Num_Barcode_Labels] [int] NULL,
	[Location] [nvarchar](20) NULL,
	[DeviceID] [nvarchar](20) NOT NULL,
	[IsChanged] [bit] NULL,
	[IsNew] [bit] NULL,
	[Tax_1] [bit] NULL,
	[Tax_2] [bit] NULL,
	[Tax_3] [bit] NULL,
	[Tax_4] [bit] NULL,
	[Tax_5] [bit] NULL,
	[Tax_6] [bit] NULL,
	[ReOrder_Cost] [decimal](25, 8) NULL,
	[Reorder_Level] [decimal](25, 8) NULL,
	[Reorder_Quantity] [decimal](25, 8) NULL,
	[Check_ID] [bit] NULL,
	[Check_ID2] [bit] NULL,
	[Unit_Size] [decimal](25, 8) NULL,
	[Unit_Type] [nvarchar](10) NULL,
	[FoodStampable] [bit] NULL,
	[NumPerCase] [int] NULL,
	[CostPer] [money] NOT NULL,
	[Case_Cost] [money] NOT NULL,
	[ItemName_Extra] [nvarchar](40) NULL,
 CONSTRAINT [pkMobileApp_Inventory] PRIMARY KEY CLUSTERED 
(
	[ItemNum] ASC,
	[Store_ID] ASC,
	[DeviceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MobileApp_Inventory_SKUS]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MobileApp_Inventory_SKUS](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[AltSKU] [nvarchar](30) NOT NULL,
	[DeviceID] [nvarchar](20) NOT NULL,
	[IsChanged] [bit] NULL,
 CONSTRAINT [pkMobileApp_Inventory_SKUS] PRIMARY KEY CLUSTERED 
(
	[ItemNum] ASC,
	[Store_ID] ASC,
	[DeviceID] ASC,
	[AltSKU] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Modifier_Groups]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Modifier_Groups](
	[ID] [nvarchar](10) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Description] [nvarchar](20) NULL,
	[Default_Prompt] [nvarchar](30) NULL,
	[PrintOrder] [int] NULL,
 CONSTRAINT [pkModifier_Groups] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Modifier_Groups_Details]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Modifier_Groups_Details](
	[ID] [nvarchar](10) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[Description] [nvarchar](30) NULL,
	[Quantity] [decimal](25, 8) NULL,
	[Price] [decimal](25, 8) NULL,
	[Index] [int] NULL,
 CONSTRAINT [pkModifier_Groups_Details] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Modifier_Groups_SubMods]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Modifier_Groups_SubMods](
	[ID] [nvarchar](10) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Caption] [nvarchar](15) NULL,
	[Quan_Modifier] [real] NULL,
	[Price_Modifier] [real] NULL,
	[Index] [int] NULL,
 CONSTRAINT [pkModifier_Groups_SubMods] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Modifiers]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Modifiers](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[ModNum] [nvarchar](20) NOT NULL,
	[ModName] [nvarchar](30) NULL,
	[Dirty] [bit] NOT NULL,
	[Group_Or_Individual] [smallint] NOT NULL,
	[ChargePrice] [bit] NOT NULL,
	[NumToSelect] [nvarchar](8) NULL,
	[Prompt] [nvarchar](40) NULL,
	[Index] [int] NOT NULL,
	[Forced] [bit] NOT NULL,
	[RowID] [uniqueidentifier] NOT NULL,
 CONSTRAINT [pkModifiers] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Money_Activity]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Money_Activity](
	[Index] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[TransactionNumber] [bigint] NOT NULL,
	[PaymentType] [smallint] NOT NULL,
	[DateTime] [datetime] NULL,
	[TransactionType] [smallint] NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[Amount] [money] NULL,
	[CurrentConversionRate] [float] NULL,
	[SubInvoiceNumber] [int] NULL,
	[ReferenceNumber] [int] NULL,
	[TenderAmount] [money] NULL,
	[Station_ID] [nvarchar](5) NULL,
	[FleetCardAmount] [money] NULL,
	[IsRefundable] [bit] NULL,
 CONSTRAINT [pkMoney_Activity] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Index] ASC,
	[TransactionNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[OnlineOrdering_Status_Enum]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OnlineOrdering_Status_Enum](
	[Store_Id] [nvarchar](10) NOT NULL,
	[Id] [int] NOT NULL,
	[Position] [int] NULL,
	[Description] [nvarchar](200) NULL,
 CONSTRAINT [pkOnlineOrdering_Status_Enum] PRIMARY KEY CLUSTERED 
(
	[Store_Id] ASC,
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[OrderQueueItems]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OrderQueueItems](
	[StoreID] [nvarchar](10) NULL,
	[StationID] [nvarchar](5) NULL,
	[QueueID] [uniqueidentifier] NULL,
	[ObjectID] [uniqueidentifier] NOT NULL,
	[Quantity] [decimal](25, 8) NULL,
 CONSTRAINT [pkOrderQueueItems] PRIMARY KEY CLUSTERED 
(
	[ObjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[OrderQueueSummary]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OrderQueueSummary](
	[StoreID] [nvarchar](10) NULL,
	[StationID] [nvarchar](5) NULL,
	[QueueID] [uniqueidentifier] NOT NULL,
	[Accepted] [bit] NULL,
	[DueDateTime] [datetime] NULL,
	[HasProblems] [bit] NULL,
	[InvoiceNumber] [bigint] NULL,
	[Notes] [nvarchar](255) NULL,
	[QueuedDateTime] [datetime] NULL,
	[OrderType] [int] NULL,
	[SendCopyNow] [bit] NULL,
	[Visible] [bit] NULL,
	[ParentQueueID] [uniqueidentifier] NULL,
 CONSTRAINT [pkOrderQueueSummary] PRIMARY KEY CLUSTERED 
(
	[QueueID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PackageItems]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PackageItems](
	[RowID] [uniqueidentifier] NOT NULL,
	[ParentRowID] [nvarchar](40) NULL,
	[ItemRowID] [nvarchar](40) NULL,
	[QtyShipped] [decimal](25, 8) NULL,
	[QtyReceived] [decimal](25, 8) NULL,
	[QtyDamaged] [decimal](25, 8) NULL,
	[QtyLost] [decimal](25, 8) NULL,
	[Cost] [decimal](25, 8) NULL,
 CONSTRAINT [pkPackageItems] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Packages]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Packages](
	[RowID] [uniqueidentifier] NOT NULL,
	[ParentRowID] [nvarchar](40) NULL,
	[Weight] [real] NULL,
	[PackageValue] [money] NULL,
	[Carrier] [nvarchar](10) NULL,
	[ShipMethod] [nvarchar](15) NULL,
	[ShipCost] [money] NULL,
	[InsuredValue] [money] NULL,
	[TrackingNumber] [nvarchar](20) NULL,
	[ShipDate] [datetime] NULL,
	[EstimatedDate] [datetime] NULL,
	[Notes] [ntext] NULL,
	[Status] [int] NULL,
	[Store_ID] [nvarchar](10) NULL,
 CONSTRAINT [pkPackages] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Payment_Processing_Config]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Payment_Processing_Config](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Station_ID] [nvarchar](5) NOT NULL,
	[PaymentMethod] [int] NOT NULL,
	[ClassAssemblyName] [nvarchar](200) NULL,
	[PrimaryUrl] [nvarchar](100) NULL,
	[SecondaryUrl] [nvarchar](100) NULL,
	[MerchantNumber] [nvarchar](150) NOT NULL,
	[ClientNumber] [nvarchar](150) NULL,
	[TerminalNumber] [nvarchar](20) NULL,
	[UserName] [nvarchar](150) NULL,
	[Password] [nvarchar](400) NULL,
	[ProcessingCompany] [nvarchar](max) NULL,
	[PortNumber] [nvarchar](10) NULL,
	[FilePath] [nvarchar](75) NULL,
	[UserFriendlyName] [nvarchar](100) NULL,
	[TimeOut] [int] NULL,
	[Require_Cvv2] [bit] NULL,
	[Process_Offline] [bit] NULL,
	[IsCanadianDebitProcessor] [bit] NULL,
	[IsCheckNumberVerification] [bit] NULL,
	[IsCheckDriversLicenceVerification] [bit] NULL,
	[IsCheckAccountNumberVerification] [bit] NULL,
	[IsCheckFullMICRVerification] [bit] NULL,
	[IsCheckPhoneNumberVerification] [bit] NULL,
	[ProcessOffline] [bit] NULL,
	[DefaultMerchant] [int] NULL,
	[SecondaryProcessingCompany] [nvarchar](max) NULL,
	[SecondaryMerchantNumber] [nvarchar](75) NULL,
	[CheckTransactionType] [int] NULL,
	[PosID] [nvarchar](20) NULL,
	[RoutingID] [nvarchar](20) NULL,
	[AuthenticationCode] [nvarchar](20) NULL,
	[AuthenticationFactor1] [nvarchar](50) NULL,
	[AuthenticationFactor2] [nvarchar](20) NULL,
	[ProcessDebitCardsUsingCreditProcessor] [bit] NULL,
	[SecondaryTerminalNumber] [nvarchar](30) NULL,
	[AltMerchantNumber] [nvarchar](30) NULL,
	[PrimaryPhoneNumber] [nvarchar](15) NULL,
	[SecondaryPhoneNumber] [nvarchar](15) NULL,
	[AVSType] [int] NULL,
	[SupportsTrack11WithoutSentinel] [bit] NULL,
	[SupportsTokenization] [bit] NULL,
	[MobileBusinessType] [int] NULL,
	[TimeoutForBackGroundChecking] [int] NOT NULL,
	[CaptureType] [int] NOT NULL,
	[BlindRefund] [bit] NULL,
	[SupportPoleDisplay] [bit] NULL,
	[PinPadIpAddress] [nvarchar](100) NULL,
	[PinPadPortNumber] [nvarchar](60) NULL,
	[PinPadConnectionType] [int] NOT NULL,
	[UnlockCode] [nvarchar](max) NULL,
 CONSTRAINT [pkPayment_Processing_Config] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Station_ID] ASC,
	[PaymentMethod] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Payment_Processing_SequenceNumber]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Payment_Processing_SequenceNumber](
	[Station_ID] [nvarchar](12) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[BatchNumber] [int] NULL,
	[RecordNumber] [int] NULL,
 CONSTRAINT [pkPayment_Processing_SequenceNumber] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Station_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Payment_Processing_Store_SequenceNumber]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Payment_Processing_Store_SequenceNumber](
	[Store_ID] [nvarchar](8) NOT NULL,
	[SequenceNumber] [int] NULL,
 CONSTRAINT [pkPayment_Processing_Store_SequenceNumber] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Payment_Types]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Payment_Types](
	[PaymentType] [smallint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[LongDescription] [varchar](50) NULL,
	[ShortDescription] [nvarchar](4) NULL,
	[OpensCashDrawer] [bit] NULL,
	[NumReceipts] [smallint] NULL,
	[PromptSignature] [bit] NULL,
	[PrimaryCurrency] [bit] NULL,
	[ConversionRate] [float] NULL,
	[StoredBalance] [bit] NULL,
	[RequireID] [bit] NULL,
	[NumDaysIDValid] [smallint] NULL,
	[Visible] [bit] NULL,
	[Processes] [bit] NULL,
	[ProcessType] [nvarchar](1) NULL,
	[MediaType] [smallint] NULL,
	[TaxExempt] [bit] NULL,
	[RequiresPinNumber] [bit] NULL,
	[RequiresCustomerSelection] [bit] NULL,
	[MerchantNumber] [nvarchar](40) NULL,
	[Processor] [nvarchar](10) NULL,
	[PaymentVerificationLocation] [nvarchar](50) NULL,
	[RequiresPermission] [bit] NULL,
 CONSTRAINT [pkPayment_Types] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PaymentType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Payout_Accounting_Transaction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Payout_Accounting_Transaction](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[Id] [int] NOT NULL,
	[Txn_Id] [nvarchar](20) NULL,
	[EditSequence] [nvarchar](15) NULL,
	[TxnLineId] [nvarchar](20) NULL,
 CONSTRAINT [pkPayout_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Vendor_Number] ASC,
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Pending_Orders]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pending_Orders](
	[Area] [nvarchar](15) NOT NULL,
	[Time_Started] [datetime] NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[Station_ID] [nvarchar](10) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[OnHoldID] [nvarchar](12) NULL,
	[Status] [smallint] NULL,
	[Completed] [bit] NOT NULL,
 CONSTRAINT [pkPending_Orders] PRIMARY KEY CLUSTERED 
(
	[Area] ASC,
	[Store_ID] ASC,
	[Invoice_Number] ASC,
	[Station_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Pending_Orders_ItemRoutes]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pending_Orders_ItemRoutes](
	[ObjectID] [nvarchar](40) NOT NULL,
	[ParentObjectID] [nvarchar](40) NULL,
	[Store_ID] [nvarchar](10) NULL,
	[Location] [int] NULL,
	[SequenceNumber] [int] NULL,
	[Status] [int] NULL,
	[RouteNumber] [int] NULL,
 CONSTRAINT [pkPending_Orders_ItemRoutes] PRIMARY KEY CLUSTERED 
(
	[ObjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Pending_Orders_Items]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pending_Orders_Items](
	[Area] [nvarchar](15) NOT NULL,
	[Invoice_Number] [bigint] NOT NULL,
	[ItemName] [nvarchar](40) NOT NULL,
	[Quan] [float] NULL,
	[IsModifier] [bit] NOT NULL,
	[Time_Started] [datetime] NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[LineNum] [int] NULL,
	[ObjectID] [nvarchar](40) NOT NULL,
	[ParentObjectID] [nvarchar](40) NULL,
	[Station_ID] [nvarchar](5) NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[OnHoldID] [nvarchar](12) NULL,
	[Priority] [int] NULL,
	[ForeColor] [int] NULL,
	[BackColor] [int] NULL,
	[ItemNum] [nvarchar](30) NULL,
	[Progress] [int] NULL,
	[PaidStatus] [int] NULL,
	[OrderType] [int] NULL,
	[Identifier] [nvarchar](30) NULL,
	[TransferFromID] [nvarchar](12) NULL,
	[TransferToID] [nvarchar](12) NULL,
 CONSTRAINT [pkPending_Orders_Items] PRIMARY KEY CLUSTERED 
(
	[ObjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Permissions]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Permissions](
	[PermissionID] [int] NOT NULL,
	[ShortDescription] [nvarchar](100) NULL,
	[LongDescription] [nvarchar](500) NULL,
	[PermissionType] [int] NULL,
	[Category] [int] NULL,
 CONSTRAINT [pkPermissions] PRIMARY KEY CLUSTERED 
(
	[PermissionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PickList]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PickList](
	[RowID] [uniqueidentifier] NOT NULL,
	[Store_ID] [nvarchar](10) NULL,
	[Station_ID] [nvarchar](10) NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[ItemData] [nvarchar](4000) NULL,
	[Creation_Date] [datetime] NULL,
	[Processed] [bit] NULL,
 CONSTRAINT [PK_PickList] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PinPad_VersionInfo]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PinPad_VersionInfo](
	[SerialNumber] [nvarchar](10) NULL,
	[Version] [nvarchar](10) NOT NULL,
	[CreationDate] [datetime] NOT NULL,
 CONSTRAINT [pk_PinPad_VersionInfo] PRIMARY KEY CLUSTERED 
(
	[Version] ASC,
	[CreationDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Pizza_Modifier_SubModifiers]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pizza_Modifier_SubModifiers](
	[PizzaItemNum] [nvarchar](20) NOT NULL,
	[ModifierItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[SubModifierNumber] [nvarchar](20) NOT NULL,
	[PizzaRegion] [int] NOT NULL,
 CONSTRAINT [pkPizza_Modifier_SubModifiers] PRIMARY KEY CLUSTERED 
(
	[PizzaItemNum] ASC,
	[ModifierItemNum] ASC,
	[Store_ID] ASC,
	[SubModifierNumber] ASC,
	[PizzaRegion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Pizza_Modifiers]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pizza_Modifiers](
	[PizzaItemNum] [nvarchar](20) NOT NULL,
	[ModifierItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[PizzaRegion] [int] NOT NULL,
 CONSTRAINT [pkPizza_Modifiers] PRIMARY KEY CLUSTERED 
(
	[PizzaItemNum] ASC,
	[ModifierItemNum] ASC,
	[Store_ID] ASC,
	[PizzaRegion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Pizza_Prices]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pizza_Prices](
	[PizzaItemNum] [nvarchar](20) NOT NULL,
	[SizeItemNum] [nvarchar](20) NOT NULL,
	[CrustItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Price] [money] NULL,
 CONSTRAINT [pkPizza_Prices] PRIMARY KEY CLUSTERED 
(
	[PizzaItemNum] ASC,
	[SizeItemNum] ASC,
	[CrustItemNum] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Pizza_Regions]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pizza_Regions](
	[ID] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Name] [nvarchar](20) NULL,
	[PriceMultiplier] [float] NULL,
	[QuantityMultiplier] [float] NULL,
 CONSTRAINT [pkPizza_Regions] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Pizza_Topping_Prices]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pizza_Topping_Prices](
	[ToppingItemNum] [nvarchar](20) NOT NULL,
	[SizeItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Price] [float] NULL,
 CONSTRAINT [pkPizza_Topping_Prices] PRIMARY KEY CLUSTERED 
(
	[ToppingItemNum] ASC,
	[SizeItemNum] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PO_Authorizations]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PO_Authorizations](
	[PO_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[Signature] [nvarchar](30) NULL,
 CONSTRAINT [pkPO_Authorizations] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PO_Number] ASC,
	[Cashier_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PO_Charges]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PO_Charges](
	[PO_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Index] [smallint] NOT NULL,
	[Description] [nvarchar](30) NULL,
	[Amount] [money] NULL,
 CONSTRAINT [pkPO_Charges] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PO_Number] ASC,
	[Index] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PO_Details]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PO_Details](
	[PO_Number] [bigint] NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[LineNum] [int] NOT NULL,
	[Quan_Ordered] [float] NULL,
	[CostPer] [money] NOT NULL,
	[Quan_Received] [float] NULL,
	[Vendor_Part_Number] [nvarchar](20) NULL,
	[CasePack] [float] NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[destStore_ID] [nvarchar](10) NULL,
	[Current_Batch_Quan] [float] NULL,
	[Quan_Damaged] [float] NULL,
	[Reason] [nvarchar](30) NULL,
	[NumberPerCase] [float] NULL,
	[OverrideCommission] [bit] NULL,
	[Quan_OutofDate] [float] NULL,
 CONSTRAINT [pkPO_Details] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PO_Number] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PO_Details_CostDisc]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PO_Details_CostDisc](
	[PO_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[LineNum] [int] NOT NULL,
	[Desc1] [nvarchar](15) NULL,
	[Amt1] [decimal](25, 8) NULL,
	[Type1] [int] NULL,
	[Desc2] [nvarchar](15) NULL,
	[Amt2] [decimal](25, 8) NULL,
	[Type2] [int] NULL,
	[Desc3] [nvarchar](15) NULL,
	[Amt3] [decimal](25, 8) NULL,
	[Type3] [int] NULL,
 CONSTRAINT [pkPO_Details_CostDisc] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PO_Number] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PO_Details_StoreListing]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PO_Details_StoreListing](
	[PO_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[LineNum] [int] NOT NULL,
	[destStore_ID] [nvarchar](10) NULL,
	[Quan_Ordered] [decimal](25, 8) NULL,
	[Quan_Received] [decimal](25, 8) NULL,
	[CasePack] [int] NULL,
	[Quan_Damaged] [decimal](25, 8) NULL,
	[Current_Batch_Quan] [decimal](25, 8) NULL,
	[Quan_OutofDate] [float] NULL,
 CONSTRAINT [pkPO_Details_StoreListing] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PO_Number] ASC,
	[LineNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PO_Payments]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PO_Payments](
	[PO_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[Payment_Method] [nvarchar](2) NULL,
	[Amount] [money] NULL,
	[Reference_Number] [nvarchar](12) NULL,
	[Index] [smallint] NOT NULL,
	[Payment_ID] [int] NULL,
	[Description] [nvarchar](60) NULL,
 CONSTRAINT [pkPO_Payments] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PO_Number] ASC,
	[Index] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PO_Summary]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PO_Summary](
	[PO_Number] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[DateTime] [datetime] NULL,
	[Reference] [nvarchar](15) NULL,
	[Vendor_Number] [nvarchar](12) NULL,
	[Total_Cost] [money] NULL,
	[Total_Cost_Received] [money] NULL,
	[Terms] [nvarchar](15) NULL,
	[Due_Date] [datetime] NULL,
	[Ship_Via] [nvarchar](15) NULL,
	[ShipTo_1] [nvarchar](55) NULL,
	[ShipTo_2] [nvarchar](55) NULL,
	[ShipTo_3] [nvarchar](55) NULL,
	[ShipTo_4] [nvarchar](55) NULL,
	[ShipTo_5] [nvarchar](55) NULL,
	[Instructions] [nvarchar](95) NULL,
	[Status] [nvarchar](1) NULL,
	[Last_Modified] [datetime] NULL,
	[Dirty] [bit] NOT NULL,
	[Cashier_ID] [nvarchar](10) NULL,
	[Billable_Department] [nvarchar](20) NULL,
	[ShipTo_Destination] [nvarchar](10) NULL,
	[Ordering_Mode] [smallint] NULL,
	[Fully_Authorized] [bit] NULL,
	[Print_Notes_On_PO] [bit] NULL,
	[Cancel_Date] [datetime] NULL,
	[Total_Charges] [money] NULL,
	[Fully_Paid] [bit] NULL,
	[POType] [int] NULL,
	[ExpectedAmountToReceive] [int] NULL,
	[Order_Reason] [nvarchar](30) NULL,
	[Distributor] [nvarchar](15) NULL,
 CONSTRAINT [pkPO_Summary] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PO_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PO_Summary_Accounting_Transaction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PO_Summary_Accounting_Transaction](
	[Store_ID] [nvarchar](10) NOT NULL,
	[PO_Number] [bigint] NOT NULL,
	[Txn_Id] [nvarchar](50) NOT NULL,
	[EditSequence] [nvarchar](50) NULL,
	[Tran_Type] [int] NOT NULL,
 CONSTRAINT [pkPO_Summary_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[PO_Number] ASC,
	[Tran_Type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PriceBatch]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PriceBatch](
	[BatchID] [uniqueidentifier] NOT NULL,
	[BatchCreateDate] [datetime] NULL,
	[CreationLocation] [int] NULL,
	[EffectiveDate] [datetime] NULL,
	[ExpirationDate] [datetime] NULL,
 CONSTRAINT [pkPriceBatch] PRIMARY KEY CLUSTERED 
(
	[BatchID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PriceBatchDetail]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PriceBatchDetail](
	[BatchID] [uniqueidentifier] NOT NULL,
	[DetailID] [uniqueidentifier] NOT NULL,
	[Identifier] [nvarchar](20) NULL,
	[IdentifierType] [int] NULL,
	[PriceChangeType] [int] NULL,
	[Amount] [decimal](25, 8) NULL,
	[ApplicationMethod] [int] NULL,
	[Quantity] [decimal](25, 8) NULL,
	[StartDate] [datetime] NULL,
	[EndDate] [datetime] NULL,
	[Description] [nvarchar](30) NULL,
 CONSTRAINT [pkPriceBatchDetail] PRIMARY KEY CLUSTERED 
(
	[BatchID] ASC,
	[DetailID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PriceBatchStoreDetail]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PriceBatchStoreDetail](
	[BatchID] [uniqueidentifier] NOT NULL,
	[DetailID] [uniqueidentifier] NOT NULL,
	[StoreID] [nvarchar](10) NOT NULL,
	[Accepted] [bit] NULL,
	[Overrided] [bit] NULL,
	[Amount] [decimal](25, 8) NULL,
	[Quantity] [decimal](25, 8) NULL,
	[StartDate] [datetime] NULL,
	[EndDate] [datetime] NULL,
 CONSTRAINT [pkPriceBatchStoreDetail] PRIMARY KEY CLUSTERED 
(
	[BatchID] ASC,
	[DetailID] ASC,
	[StoreID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PriceBatchStores]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PriceBatchStores](
	[BatchID] [uniqueidentifier] NOT NULL,
	[StoreID] [nvarchar](10) NOT NULL,
	[Applied] [bit] NULL,
 CONSTRAINT [pkPriceBatchStores] PRIMARY KEY CLUSTERED 
(
	[BatchID] ASC,
	[StoreID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Printer_Mapping]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Printer_Mapping](
	[Station_ID] [nvarchar](5) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[LocalPort] [nvarchar](20) NULL,
	[NetworkPort] [nvarchar](75) NULL,
	[PrinterName] [nvarchar](30) NOT NULL,
	[Details] [nvarchar](100) NULL,
	[Disabled] [bit] NOT NULL,
	[Two_Color_Printing] [bit] NOT NULL,
	[CutReceipt] [bit] NULL,
	[LineFeedsBeforeCut] [int] NULL,
	[PrintMasterSubordinate] [bit] NULL,
 CONSTRAINT [pkPrinter_Mapping] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Station_ID] ASC,
	[PrinterName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Printers]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Printers](
	[ItemNum] [nvarchar](20) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Port] [nvarchar](75) NOT NULL,
	[Desc] [nvarchar](50) NULL,
	[PrinterName] [nvarchar](30) NOT NULL,
 CONSTRAINT [pkPrinters] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Port] ASC,
	[PrinterName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Properties]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Properties](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Property_ID] [smallint] NOT NULL,
	[Description] [nvarchar](10) NULL,
	[AllowCustomer] [bit] NULL,
	[AllowInventory] [bit] NULL,
 CONSTRAINT [pkProperties] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Property_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Property_Values]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Property_Values](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Property_ID] [smallint] NOT NULL,
	[Value_ID] [smallint] NOT NULL,
	[Description] [nvarchar](100) NULL,
	[PurchaseType] [smallint] NULL,
 CONSTRAINT [pkProperty_Values] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Property_ID] ASC,
	[Value_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[QB_Sales_Pass_Files]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[QB_Sales_Pass_Files](
	[QB_Sales_Todays_Date] [smalldatetime] NOT NULL,
	[QB_Sales_FileName] [nvarchar](30) NOT NULL,
	[QB_Sales_FIleCounter] [int] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[QB_Sales_Undeposited_Funds] [money] NULL,
	[QB_Sales_Income] [money] NULL,
	[QB_Sales_Tax] [money] NULL,
	[QB_Sales_COGS] [money] NULL,
	[QB_Sales_Inventory] [money] NULL,
	[QB_Sales_Tax2] [money] NULL,
	[QB_Sales_Tax3] [money] NULL,
	[QB_Sales_Todays_Date_New] [smalldatetime] NULL,
 CONSTRAINT [pkQB_Sales_Pass_Files] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[QB_Sales_FileName] ASC,
	[QB_Sales_FIleCounter] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Reports_Custom]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Reports_Custom](
	[Special] [smallint] NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Title] [nvarchar](100) NULL,
	[Description] [nvarchar](255) NULL,
	[Report_Type] [smallint] NULL,
	[Author] [nvarchar](100) NULL,
	[Create_Date] [datetime] NULL,
	[Report_Definition] [ntext] NULL,
	[SuppressZeros] [bit] NULL,
	[PrintCompanyHeader] [bit] NULL,
	[PrintCompanyHeaderAllPages] [bit] NULL,
	[PrintSubTotalsEveryPage] [bit] NULL,
	[PrintSubTotalsEveryGroup] [bit] NULL,
	[PrintLandscape] [bit] NULL,
	[GUIDident] [nvarchar](40) NOT NULL,
 CONSTRAINT [pkReports_Custom] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[GUIDident] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Reports_Setup]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Reports_Setup](
	[Store_ID] [nvarchar](10) NOT NULL,
	[DDR_BD_PAYTYPES] [bit] NOT NULL,
	[DDR_BD_DEPT] [bit] NOT NULL,
	[DDR_BD_ITEMS_SOLD] [bit] NOT NULL,
	[DDR_BD_AR_PAYTYPES] [bit] NOT NULL,
	[DDR_Print_Costs] [bit] NOT NULL,
	[DDR_ZOut] [bit] NOT NULL,
	[DDR_Payouts] [bit] NOT NULL,
	[DDR_Line_Disc] [bit] NOT NULL,
	[DDR_Total_BuyBacks] [bit] NOT NULL,
	[DDR_BD_Categories] [bit] NOT NULL,
	[DDR_Performance] [bit] NOT NULL,
	[Report_StartDate] [int] NULL,
	[Report_EndDate] [int] NULL,
	[Report_StartTime] [datetime] NULL,
	[Report_EndTime] [datetime] NULL,
	[DDR_BD_lncludeDiscountsInTotalItemPrice] [bit] NULL,
	[Report_HideDisabled] [bit] NOT NULL,
	[DDR_BD_UseSecondaryCurrencyTendered] [bit] NULL,
	[Disable_EOD_Sales_Totals] [bit] NULL,
	[Disable_EOD_Deposit_Breakdown] [bit] NULL,
	[Disable_EOD_Sales_Breakdown] [bit] NULL,
	[Print_Customer_Notes] [bit] NULL,
 CONSTRAINT [pkReports_Setup] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Schedule]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Schedule](
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[CustNum] [nvarchar](12) NULL,
	[Description] [nvarchar](40) NULL,
	[StartDateTime] [datetime] NOT NULL,
	[EndDateTime] [datetime] NOT NULL,
	[Type] [nvarchar](1) NULL,
	[Tip_Amount] [money] NULL,
	[NumMinutes] [int] NULL,
	[WagesEarned] [money] NULL,
	[WageTaxes] [money] NULL,
	[Dirty] [bit] NOT NULL,
	[AssignedJobCode] [nvarchar](15) NULL,
	[RowID] [uniqueidentifier] NOT NULL,
 CONSTRAINT [pkSchedule] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Schedule_Breaks]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Schedule_Breaks](
	[RowID] [uniqueidentifier] NOT NULL,
	[ParentRowID] [uniqueidentifier] NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Reason] [nvarchar](30) NULL,
	[StartDateTime] [datetime] NULL,
	[EndDateTime] [datetime] NULL,
 CONSTRAINT [pkSchedule_Breaks] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SelfService_Controls]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SelfService_Controls](
	[StoreID] [nvarchar](10) NOT NULL,
	[ControlID] [int] NOT NULL,
	[ParentControlID] [int] NULL,
	[ControlType] [int] NULL,
	[ControlName] [nvarchar](255) NULL,
	[BackColor] [nvarchar](25) NULL,
	[ForeColor] [nvarchar](25) NULL,
	[Text] [nvarchar](255) NULL,
	[TextFont] [nvarchar](50) NULL,
	[TextFontSize] [real] NULL,
	[TextAlignment] [int] NULL,
	[PictureURI] [nvarchar](255) NULL,
	[PictureSizeMode] [int] NULL,
	[ClickTarget] [nvarchar](40) NULL,
	[ClickTargetType] [int] NULL,
	[RelativePosition] [int] NULL,
	[PictureAlignment] [int] NULL,
	[BackColorSelected] [nvarchar](12) NULL,
	[Identifier] [uniqueidentifier] NULL,
	[ModifierParentItemNum] [nvarchar](20) NULL,
	[ModifierGroupNum] [nvarchar](20) NULL,
 CONSTRAINT [pkSelfService_Controls] PRIMARY KEY CLUSTERED 
(
	[StoreID] ASC,
	[ControlID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Setup_Corp]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Setup_Corp](
	[LastIN] [bigint] NULL,
	[Version] [real] NOT NULL,
 CONSTRAINT [pkSetup_Corp] PRIMARY KEY CLUSTERED 
(
	[Version] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Setup_DiscLevels]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Setup_DiscLevels](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Level] [nvarchar](1) NOT NULL,
	[Percent] [real] NULL,
 CONSTRAINT [pkSetup_DiscLevels] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Level] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Setup_Reason_Codes]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Setup_Reason_Codes](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Reason_Code] [nvarchar](30) NOT NULL,
	[Reason_Type] [smallint] NOT NULL,
 CONSTRAINT [pkSetup_Reason_Codes] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Reason_Code] ASC,
	[Reason_Type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Setup_TS_Buttons]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Setup_TS_Buttons](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Station_ID] [nvarchar](5) NOT NULL,
	[Index] [int] NOT NULL,
	[Caption] [nvarchar](30) NULL,
	[Picture] [nvarchar](100) NULL,
	[Function] [int] NOT NULL,
	[Option1] [nvarchar](30) NULL,
	[BackColor] [int] NULL,
	[ForeColor] [int] NULL,
	[Visible] [bit] NOT NULL,
	[BtnType] [smallint] NOT NULL,
	[Ident] [nvarchar](20) NOT NULL,
	[ScheduleIndex] [smallint] NOT NULL,
	[RowID] [uniqueidentifier] NOT NULL,
	[Option2] [nvarchar](255) NULL,
	[Option3] [nvarchar](255) NULL,
	[Option4] [bit] NULL,
	[HideCaption] [bit] NOT NULL,
 CONSTRAINT [pkSetup_TS_Buttons] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Setup_TS_Buttons_Schedule]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Setup_TS_Buttons_Schedule](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Station_ID] [nvarchar](5) NOT NULL,
	[ScheduleIndex] [int] NOT NULL,
	[StartDate] [datetime] NULL,
	[EndDate] [datetime] NULL,
	[Description] [nvarchar](30) NULL,
	[IsHoliday] [bit] NULL,
	[UseDateRange] [bit] NULL,
 CONSTRAINT [pkSetup_TS_Buttons_Schedule] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ScheduleIndex] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Setup_TS_Buttons_Schedule_DaysTimes]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Setup_TS_Buttons_Schedule_DaysTimes](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ScheduleIndex] [int] NOT NULL,
	[DayNumber] [int] NOT NULL,
	[StartTime] [datetime] NOT NULL,
	[EndTime] [datetime] NOT NULL,
 CONSTRAINT [pkSetup_TS_Buttons_Schedule_DaysTimes] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ScheduleIndex] ASC,
	[DayNumber] ASC,
	[StartTime] ASC,
	[EndTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SetupRestaurantCourses]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SetupRestaurantCourses](
	[CourseID] [uniqueidentifier] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Course] [nvarchar](20) NULL,
	[SuggestedSelection] [bit] NULL,
	[ForcedSelection] [bit] NULL,
	[CourseOrderNumber] [int] NOT NULL,
 CONSTRAINT [pkSetupRestaurantCourses] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[CourseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SetupRestaurantCoursesDepartments]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SetupRestaurantCoursesDepartments](
	[CourseID] [uniqueidentifier] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Dept_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkSetupRestaurantCoursesDepartments] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Dept_ID] ASC,
	[CourseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Shifts]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Shifts](
	[RowID] [nvarchar](40) NOT NULL,
	[ShiftID] [nvarchar](20) NULL,
	[Store_ID] [nvarchar](10) NULL,
	[StartDateTime] [datetime] NULL,
	[EndDateTime] [datetime] NULL,
	[IDUsed] [nvarchar](10) NULL,
	[NetSalesTaxed] [money] NULL,
	[NetSalesNonTaxed] [money] NULL,
	[NetSalesTaxExempt] [money] NULL,
	[Tax1] [money] NULL,
	[Tax2] [money] NULL,
	[Tax3] [money] NULL,
	[TaxOther] [money] NULL,
	[TotalNumTrans] [int] NULL,
	[Open_Cashier_ID] [nvarchar](10) NULL,
	[Close_Cashier_ID] [nvarchar](10) NULL,
	[Close_Out_Index] [bigint] NULL,
	[CashbackAmount] [money] NULL,
	[Tax4] [money] NULL,
	[Tax5] [money] NULL,
	[Tax6] [money] NULL,
 CONSTRAINT [ShiftsPK] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ShiftsMediaTypes]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ShiftsMediaTypes](
	[RowID] [nvarchar](40) NOT NULL,
	[MediaType] [int] NOT NULL,
	[MediaTotal] [money] NULL,
	[NumSales] [bigint] NULL,
	[Payouts] [money] NULL,
	[SafeDrops] [money] NULL,
	[TipsCollected] [money] NULL,
	[Store_ID] [nvarchar](10) NULL,
	[Cashback] [money] NULL,
	[DrawerDeposit] [money] NOT NULL,
 CONSTRAINT [ShiftsMediaTypesPK] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC,
	[MediaType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ShiftsMediaTypesCount]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ShiftsMediaTypesCount](
	[RowID] [nvarchar](40) NOT NULL,
	[MediaType] [int] NOT NULL,
	[OpenAmount] [money] NULL,
	[CloseAmount] [money] NULL,
	[SuggestedOpenAmount] [money] NULL,
	[OverShort] [money] NULL,
	[Store_ID] [nvarchar](10) NULL,
 CONSTRAINT [ShiftsMediaTypesCountPK] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC,
	[MediaType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ShiftsMediaTypesSubTypes]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ShiftsMediaTypesSubTypes](
	[RowID] [nvarchar](40) NOT NULL,
	[MediaType] [int] NOT NULL,
	[MediaSubType] [nvarchar](10) NOT NULL,
	[TotalAmount] [money] NULL,
	[NumSales] [money] NULL,
 CONSTRAINT [ShiftsMediaTypesSubTypesPK] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC,
	[MediaType] ASC,
	[MediaSubType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Stations]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Stations](
	[Station_ID] [nvarchar](5) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[CSO] [int] NOT NULL,
	[DSO] [int] NOT NULL,
	[ISO] [int] NOT NULL,
	[VSO] [int] NOT NULL,
	[CDL] [nvarchar](100) NULL,
	[PDL] [nvarchar](50) NULL,
	[Pole_Type] [int] NULL,
	[Scale_Port] [nvarchar](7) NULL,
	[Ticket_Port] [nvarchar](5) NOT NULL,
	[Voucher_Port] [nvarchar](5) NOT NULL,
	[BCB_Port] [nvarchar](5) NOT NULL,
	[SCP_700_Port] [nvarchar](7) NULL,
	[Epson_Cutter_Port] [nvarchar](5) NOT NULL,
	[Printer_Type] [int] NOT NULL,
	[Printer_Port] [nvarchar](5) NULL,
	[Show_Cust_Display] [bit] NOT NULL,
	[Show_Toolbar] [bit] NOT NULL,
	[API] [nvarchar](1) NOT NULL,
	[Receipt_Format] [int] NOT NULL,
	[Deadbeat_Control] [bit] NOT NULL,
	[Prompt_Amt_Tend] [bit] NOT NULL,
	[Prompt_Table] [bit] NOT NULL,
	[Prompt_ID] [bit] NOT NULL,
	[Prompt_Salesperson] [bit] NOT NULL,
	[Logo_Type] [int] NULL,
	[Logo_Loc] [nvarchar](100) NULL,
	[Order_Dest] [nvarchar](100) NULL,
	[Stock_Prompt] [bit] NOT NULL,
	[numReceiptCopies] [int] NULL,
	[Dirty] [bit] NOT NULL,
	[InvScreen] [smallint] NULL,
	[FullSize_Printer] [nvarchar](100) NULL,
	[Idle_LogOut] [int] NULL,
	[CCTip] [int] NULL,
	[Prompt_Zip] [bit] NOT NULL,
	[Last_DDR] [datetime] NULL,
	[Use_Sig_Pad_CC] [bit] NOT NULL,
	[Require_Swipe] [int] NULL,
	[Receipt_Printer] [nvarchar](100) NULL,
	[Report_Printer] [nvarchar](100) NULL,
	[Full_Receipt_Printer] [nvarchar](100) NULL,
	[Slip_Printer] [nvarchar](100) NULL,
	[DispTaxInPrice] [bit] NOT NULL,
	[numDocketCopies] [smallint] NULL,
	[CC_Proc_Drive] [nvarchar](50) NULL,
	[Check_Speed_Entry] [bit] NOT NULL,
	[Prompt_Party_Size] [bit] NOT NULL,
	[Order_By_Guest] [int] NULL,
	[Label_Printer] [nvarchar](100) NULL,
	[SigPadPort] [nvarchar](10) NULL,
	[TS_Custom] [bit] NOT NULL,
	[AmtTendScreen] [smallint] NULL,
	[Def_OrderType] [int] NULL,
	[Allow_End_Trans] [int] NULL,
	[Prompt_Another_Order] [bit] NOT NULL,
	[PinPad_Type] [smallint] NULL,
	[PinPad_Port] [nvarchar](7) NULL,
	[Login_Background] [int] NULL,
	[Login_Foreground] [int] NULL,
	[Login_Picture] [nvarchar](125) NULL,
	[Login_AlphaNum] [int] NULL,
	[Record_CashierID] [bit] NOT NULL,
	[Change_Display] [smallint] NULL,
	[Quick_Tender] [bit] NOT NULL,
	[Notify_Exp_Member] [bit] NOT NULL,
	[Station_Merchant] [smallint] NULL,
	[Item_OnTheFly] [smallint] NULL,
	[Disp_Sec_Desc] [bit] NOT NULL,
	[Print_Epson_Logo] [bit] NOT NULL,
	[Quick_Bar] [bit] NOT NULL,
	[Use_Cash_Alerts] [bit] NOT NULL,
	[Kitchen_Require_Name] [bit] NOT NULL,
	[OverPayment_As_Tip] [smallint] NULL,
	[TS_StockLevel] [smallint] NULL,
	[BarcodeOnHold] [bit] NOT NULL,
	[CD_Open] [smallint] NULL,
	[OnHold_Use_Invoice_Number] [smallint] NULL,
	[PicPath] [nvarchar](75) NULL,
	[SigPadType] [smallint] NULL,
	[AcceptSigs] [smallint] NULL,
	[SuppressSigCopy] [bit] NOT NULL,
	[MultipleMenus] [bit] NOT NULL,
	[Last_Invoice_Number] [bigint] NULL,
	[Receipt_Display_ItemCount] [bit] NULL,
	[AllowSwipeFromInvoice] [bit] NULL,
	[Scale_Port2] [nvarchar](7) NULL,
	[Endorse_Printer] [nvarchar](100) NULL,
	[Fax_Printer] [nvarchar](100) NULL,
	[Last_MoneyActivity_Index] [bigint] NULL,
	[Last_TimeClock_Index] [bigint] NULL,
	[Last_ExceptionIndex] [bigint] NULL,
	[Section_ID] [nvarchar](15) NULL,
	[TABLE_HIDE_OPENTABS] [bit] NULL,
	[TABLE_HIDE_TAKEOUT] [bit] NULL,
	[TABLE_HIDE_DELIVERY] [bit] NULL,
	[TABLE_HIDE_QUICKTAB] [bit] NULL,
	[DisableTimeBasedPricing] [bit] NULL,
	[PrintSuggestedTip] [int] NULL,
	[ScaleWeightFormatting] [int] NULL,
	[Cash_Count] [int] NULL,
	[PrintDeliveryLabels] [int] NULL,
	[Role] [int] NULL,
	[CoinDispenserPort] [nvarchar](5) NULL,
	[LastCreditReferenceNo] [nvarchar](50) NULL,
	[Receipt_Printer_Logo] [nvarchar](100) NULL,
	[Current_Cash] [money] NULL,
	[UseIDScanner] [int] NULL,
	[RecallOnHoldScreen] [int] NULL,
	[CheckCashDrawerBeforeInvoice] [bit] NULL,
	[DVRCameraID] [int] NOT NULL,
	[QuickCash_EnterKey] [bit] NULL,
	[BarCodeComplete] [bit] NULL,
	[Label_Printer_Secondary] [nvarchar](100) NULL,
	[PromptIdentifier] [int] NOT NULL,
	[PromptQuantityType] [int] NULL,
	[PinpadConnectionType] [int] NULL,
	[PinpadIPAddress] [nvarchar](20) NULL,
	[PinpadIPPort] [int] NULL,
	[Prompt_TipAmount] [bit] NULL,
	[OPOSMsr] [nvarchar](50) NULL,
	[ShowInvAdjustButtonInRetail] [bit] NULL,
	[CommissionPrompt] [int] NULL,
	[PromptEmailPurchaseOrder] [bit] NULL,
	[C2_Count] [money] NOT NULL,
	[DeliScaleType] [int] NULL,
	[DeliScaleProgramPath] [nvarchar](100) NULL,
	[ScratchBoardUpdate] [bit] NULL,
	[ShowCustomerInfoAlwaysInRetail] [bit] NULL,
	[ExternalDVRClientStatus] [bit] NULL,
	[ExternalDVRClientExePath] [nvarchar](255) NULL,
	[ExternalDVRClientArgs] [nvarchar](100) NULL,
	[HoldBarTabs] [bit] NULL,
	[MSRDeviceSerialNumber] [nvarchar](30) NULL,
	[WirelessPayment] [int] NOT NULL,
	[WirelessPaymentIPPort] [nvarchar](5) NOT NULL,
	[EnableGasPumpInterface] [bit] NULL,
	[KitchenPrinter_FontSize] [int] NOT NULL,
	[Usealternatecashdrawerstatuscheck] [bit] NULL,
	[PinPad_MSRTrack] [int] NULL,
	[Current_Key] [nvarchar](100) NULL,
	[CustomerRequiredForDelivery] [bit] NULL,
	[End_Trans_Order] [int] NOT NULL,
	[Restaurant_InvGrid_TxtSize] [int] NOT NULL,
	[Show_HotButton] [bit] NULL,
	[Use_DefaultSalesperson] [bit] NOT NULL,
 CONSTRAINT [pkStations] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Station_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Stations_CD]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Stations_CD](
	[Station_ID] [nvarchar](5) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[CDL] [nvarchar](100) NULL,
	[Occupied] [bit] NULL,
	[CD_Name] [nvarchar](10) NOT NULL,
	[PrinterPos] [smallint] NULL,
 CONSTRAINT [pkStations_CD] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Station_ID] ASC,
	[CD_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Stations_DriveThruRecallStations]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Stations_DriveThruRecallStations](
	[Station_ID] [nvarchar](5) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Source_Station_ID] [nvarchar](5) NOT NULL,
 CONSTRAINT [pkStations_DriveThruRecallStations] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Station_ID] ASC,
	[Source_Station_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Store_Api_Encryption]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Store_Api_Encryption](
	[Store_Id] [nvarchar](10) NOT NULL,
	[PublicKey] [ntext] NULL,
	[PrivateKey] [ntext] NULL,
	[CreationDate] [datetime] NULL,
 CONSTRAINT [pk_Store_Api_Encryption] PRIMARY KEY CLUSTERED 
(
	[Store_Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Store_Encryption]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Store_Encryption](
	[Store_Id] [nvarchar](10) NOT NULL,
	[Key] [nvarchar](1000) NULL,
	[MD5] [nvarchar](100) NULL,
	[CreationDate] [datetime] NOT NULL,
 CONSTRAINT [pk_Store_Encryption] PRIMARY KEY CLUSTERED 
(
	[Store_Id] ASC,
	[CreationDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Store_Group]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Store_Group](
	[Store_Group_ID] [bigint] NOT NULL,
	[Description] [nvarchar](30) NULL,
 CONSTRAINT [pkStore_Group] PRIMARY KEY CLUSTERED 
(
	[Store_Group_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Store_Group_Details]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Store_Group_Details](
	[Store_Group_ID] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
 CONSTRAINT [pkStore_Group_Details] PRIMARY KEY CLUSTERED 
(
	[Store_Group_ID] ASC,
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SubModifiers]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubModifiers](
	[ID] [nvarchar](20) NOT NULL,
	[Name] [nvarchar](20) NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[PriceModifier] [float] NULL,
	[QuantityModifier] [float] NULL,
	[Position] [int] NULL,
 CONSTRAINT [pkSubModifiers] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Table_Diagram]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Table_Diagram](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Section_ID] [nvarchar](15) NOT NULL,
	[Table_Number] [nvarchar](10) NOT NULL,
	[ShapeType] [int] NULL,
	[XPos] [int] NULL,
	[YPos] [int] NULL,
	[Height] [int] NULL,
	[Width] [int] NULL,
	[Cost_Center_Index] [smallint] NULL,
	[NumSeats] [smallint] NULL,
	[ObjectType] [int] NULL,
	[Filled] [bit] NULL,
	[Description] [nvarchar](50) NULL,
	[objectColor] [bigint] NULL,
	[objectTextColor] [bigint] NULL,
 CONSTRAINT [pkTable_Diagram] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Section_ID] ASC,
	[Table_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Table_Diagram_Sections]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Table_Diagram_Sections](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Section_ID] [nvarchar](15) NOT NULL,
	[BackColor1] [bigint] NULL,
	[BackColor2] [bigint] NULL,
 CONSTRAINT [pkTable_Diagram_Sections] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Section_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tax_Rate]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tax_Rate](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Tax1_Rate] [real] NULL,
	[Tax2_Rate] [real] NULL,
	[Tax1_Name] [nvarchar](15) NULL,
	[Tax2_Name] [nvarchar](15) NULL,
	[Tax3_Name] [nvarchar](15) NULL,
	[Tax4_Name] [nvarchar](15) NULL,
	[Tax3_Rate] [real] NULL,
	[Tax4_Rate] [real] NULL,
	[Tax2OnTax1] [bit] NOT NULL,
	[Tax2Threshold] [real] NULL,
	[Tax_3_Units] [int] NULL,
	[Doughnut_Tax_Rate] [real] NOT NULL,
	[Doughnut_Tax_Rate_Threshold] [float] NOT NULL,
	[Tax1_Rate_Secondary] [real] NULL,
	[Tax2_Rate_Secondary] [real] NULL,
	[Tax3_Rate_Secondary] [real] NULL,
	[Liter_Tax_Primary] [money] NULL,
	[Liter_Tax_Secondary] [money] NULL,
	[Tax5_Rate] [real] NULL,
	[Tax6_Rate] [real] NULL,
	[Tax5_Name] [nvarchar](15) NULL,
	[Tax6_Name] [nvarchar](15) NULL,
	[Tax4_Rate_Secondary] [real] NULL,
	[Tax5_Rate_Secondary] [real] NULL,
	[Tax6_Rate_Secondary] [real] NULL,
 CONSTRAINT [pkTax_Rate] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tax_Rate_Areas]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tax_Rate_Areas](
	[Tax_Rate_ID] [int] NOT NULL,
	[Area] [nvarchar](30) NULL,
	[Description] [nvarchar](30) NULL,
	[Percent1] [real] NULL,
	[Percent2] [real] NULL,
	[Percent3] [real] NULL,
 CONSTRAINT [pkTax_Rate_Areas] PRIMARY KEY CLUSTERED 
(
	[Tax_Rate_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tax_Table]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tax_Table](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Tax_Rate] [int] NOT NULL,
	[Range_Start] [money] NULL,
	[Range_End] [money] NULL,
	[Amount] [money] NULL,
 CONSTRAINT [pkTax_Table] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Tax_Rate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Time_Clock]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Time_Clock](
	[ID] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Cashier_ID] [nvarchar](10) NOT NULL,
	[StartDateTime] [datetime] NULL,
	[EndDateTime] [datetime] NULL,
	[NumMinutes] [int] NULL,
	[Wages] [money] NULL,
	[Taxes] [money] NULL,
	[Tips] [money] NULL,
	[Status] [nvarchar](1) NULL,
	[Dirty] [bit] NOT NULL,
	[Hourly_Wage] [money] NULL,
	[JobCodeID] [nvarchar](15) NULL,
	[Drawer_Start] [money] NULL,
	[Drawer_End] [money] NULL,
	[Drawer_OverShort] [money] NULL,
	[Total_Cash_Sales] [money] NULL,
	[Total_Cash_AR_Payments] [money] NULL,
	[Total_Cash_Payouts] [money] NULL,
	[Credit_Tips_Earned] [money] NULL,
	[Credit_Tips_Taken] [money] NULL,
	[Total_Sales] [money] NULL,
	[Total_Voids] [money] NULL,
	[Total_CC_Sales] [money] NULL,
	[Total_CH_Sales] [money] NULL,
	[Total_Cash_Pickups] [money] NULL,
	[Total_Drawer_Transfers] [money] NULL,
	[Total_Found_Money] [money] NULL,
	[Cashier_Specific_Sales] [money] NULL,
	[EmergencyOverrideID] [nvarchar](10) NULL,
	[OvertimeHourly_Wage] [money] NULL,
	[OvertimeWagesEarned] [money] NULL,
	[Total_ECheck_Sales] [money] NULL,
	[State] [int] NULL,
	[Last_Delivery] [datetime] NULL,
	[Total_GC_Payments] [money] NULL,
	[ClockOutStation_ID] [nvarchar](5) NULL,
	[NumMinutesBreakUnpaid] [int] NULL,
	[NumMinutesBreakPaid] [int] NULL,
	[NonAppliedGratuityCashTips] [money] NULL,
	[CashbackAmount] [money] NULL,
	[Total_DC_Sales] [money] NULL,
	[Total_FS_Sales] [money] NULL,
	[Total_Cash_Layaway_Payments] [money] NULL,
	[Drawer_End_SecCurr] [money] NOT NULL,
	[Total_SecCurr_Sales] [money] NOT NULL,
	[Credit_Tips_Withheld] [money] NOT NULL,
	[Total_MP_Sales] [money] NULL,
	[Total_MPDiscount_Sales] [money] NULL,
	[Total_EBTCashBenefit_Sales] [money] NOT NULL,
	[Cash_Tips_Taken] [money] NULL,
 CONSTRAINT [pkTime_Clock] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Time_Clock_Breaks]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Time_Clock_Breaks](
	[ID] [bigint] NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[BreakStartDateTime] [datetime] NULL,
	[BreakEndDateTime] [datetime] NULL,
	[NumMinutesBreak] [int] NULL,
	[Description] [nvarchar](30) NULL,
	[GUIDident] [uniqueidentifier] NOT NULL,
	[Paid] [bit] NULL,
 CONSTRAINT [pkTime_Clock_Breaks] PRIMARY KEY CLUSTERED 
(
	[GUIDident] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Time_Clock_Cash_Count]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Time_Clock_Cash_Count](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ID] [bigint] NOT NULL,
	[NumPennies] [smallint] NULL,
	[NumNickels] [smallint] NULL,
	[NumDimes] [smallint] NULL,
	[NumQuarters] [smallint] NULL,
	[NumHalfDollars] [smallint] NULL,
	[NumDollars] [smallint] NULL,
	[NumFives] [smallint] NULL,
	[NumTens] [smallint] NULL,
	[NumTwenties] [smallint] NULL,
	[NumFifties] [smallint] NULL,
	[NumHundreds] [smallint] NULL,
 CONSTRAINT [pkTime_Clock_Cash_Count] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Timesheet_Accounting_Transaction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Timesheet_Accounting_Transaction](
	[Store_ID] [nvarchar](10) NOT NULL,
	[ID] [bigint] NOT NULL,
	[Txn_Id] [nvarchar](50) NULL,
	[EditSequence] [nvarchar](50) NULL,
	[Type] [int] NOT NULL,
	[SeqNo] [int] NOT NULL,
 CONSTRAINT [PK_Timesheet_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[ID] ASC,
	[Type] ASC,
	[SeqNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[User_Defined]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[User_Defined](
	[Store_ID] [nvarchar](10) NULL,
	[UD_ID] [nvarchar](10) NULL,
	[Description] [nvarchar](100) NULL,
	[Type] [nvarchar](max) NULL,
	[Type2] [nvarchar](100) NULL,
	[Type3] [nvarchar](100) NULL,
	[RowID] [uniqueidentifier] NOT NULL,
 CONSTRAINT [pkUser_Defined] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendor_Accounting_Transaction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendor_Accounting_Transaction](
	[Vendor_Number] [nvarchar](41) NOT NULL,
	[EditSequence] [nvarchar](20) NULL,
 CONSTRAINT [pkVendor_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[Vendor_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendor_Payout_Accounting_Transaction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendor_Payout_Accounting_Transaction](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[Id] [int] NOT NULL,
	[Txn_Id] [nvarchar](20) NULL,
	[EditSequence] [nvarchar](15) NULL,
	[TxnLineId] [nvarchar](20) NULL,
 CONSTRAINT [pkVendor_Payout_Accounting_Transaction] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Vendor_Number] ASC,
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendor_Store_Priorities]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendor_Store_Priorities](
	[Store_ID] [nvarchar](10) NOT NULL,
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[Index] [smallint] NULL,
	[Weight] [smallint] NULL,
 CONSTRAINT [pkVendor_Store_Priorities] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Vendor_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendor_Stores]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendor_Stores](
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[Store_ID] [nvarchar](10) NOT NULL,
	[Allow_Purchase_Orders] [bit] NULL,
	[Allow_Purchase_Now] [bit] NULL,
	[Order_Type_Allowed] [smallint] NULL,
	[Template_ID] [int] NULL,
	[Typical_Delivery_Time] [smallint] NULL,
	[Default_Instructions] [ntext] NULL,
	[Notes] [ntext] NULL,
 CONSTRAINT [pkVendor_Stores] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC,
	[Vendor_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendor_Templates]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendor_Templates](
	[Template_ID] [int] NOT NULL,
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[Template_Description] [nvarchar](50) NULL,
	[Logo_Location] [nvarchar](50) NULL,
	[Minimum_Order] [money] NULL,
 CONSTRAINT [pkVendor_Templates] PRIMARY KEY CLUSTERED 
(
	[Template_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendor_Templates_Items]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendor_Templates_Items](
	[Template_ID] [int] NOT NULL,
	[ItemNum] [nvarchar](20) NOT NULL,
	[ItemOrCase] [smallint] NULL,
 CONSTRAINT [pkVendor_Templates_Items] PRIMARY KEY CLUSTERED 
(
	[Template_ID] ASC,
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendor_Terms]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendor_Terms](
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[Terms] [nvarchar](20) NOT NULL,
	[Preferred] [bit] NULL,
 CONSTRAINT [pkVendor_Terms] PRIMARY KEY CLUSTERED 
(
	[Vendor_Number] ASC,
	[Terms] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vendors]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vendors](
	[Vendor_Number] [nvarchar](12) NOT NULL,
	[First_Name] [nvarchar](15) NULL,
	[Last_Name] [nvarchar](15) NULL,
	[Company] [nvarchar](30) NOT NULL,
	[Address_1] [nvarchar](30) NULL,
	[Address_2] [nvarchar](30) NULL,
	[City] [nvarchar](20) NULL,
	[State] [nvarchar](12) NULL,
	[Zip_Code] [nvarchar](10) NULL,
	[Phone] [nvarchar](15) NULL,
	[Fax] [nvarchar](15) NULL,
	[Vendor_Tax_ID] [nvarchar](15) NULL,
	[Vendor_Terms] [nvarchar](15) NULL,
	[SSN] [nvarchar](11) NULL,
	[Commission] [real] NULL,
	[Rent] [money] NULL,
	[Dirty] [bit] NOT NULL,
	[County] [nvarchar](30) NULL,
	[Country] [nvarchar](30) NULL,
	[Email] [nvarchar](50) NULL,
	[Website] [ntext] NULL,
	[Minimum_Order] [money] NULL,
	[Default_Ordering_Mode] [smallint] NULL,
	[Default_Billable_Department] [nvarchar](20) NULL,
	[Default_PO_Delivery] [smallint] NULL,
 CONSTRAINT [pkVendors] PRIMARY KEY CLUSTERED 
(
	[Vendor_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Virtual_Pole_Display]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Virtual_Pole_Display](
	[Store_ID] [nvarchar](10) NOT NULL,
	[TemplateType] [int] NULL,
	[HTMLTemplate] [nvarchar](255) NULL,
	[ThemeName] [nvarchar](50) NULL,
	[DisplayTime] [int] NULL,
	[ImageFolder] [nvarchar](255) NULL,
	[Logo] [nvarchar](255) NULL,
	[TextSize] [nvarchar](30) NULL,
	[DisplaySlideshow] [bit] NULL,
	[NumDisplayItems] [int] NULL,
 CONSTRAINT [pkVirtual_Pole_Display] PRIMARY KEY CLUSTERED 
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Virtual_Pole_Display_Ads]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Virtual_Pole_Display_Ads](
	[Store_ID] [nvarchar](10) NULL,
	[RowID] [uniqueidentifier] NOT NULL,
	[ImageIndex] [int] NULL,
	[AdType] [int] NULL,
	[Location] [nvarchar](255) NULL,
 CONSTRAINT [pkVirtual_Pole_Display_Ads] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxAR_Transactions_Custnum_DateTime]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxAR_Transactions_Custnum_DateTime] ON [dbo].[AR_Transactions]
(
	[CustNum] ASC,
	[DateTime] ASC
)
INCLUDE([AmountRemaining]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxAR_Transactions_StoreID_CustNum_AmountRemaining_TransAmount_DateTime]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxAR_Transactions_StoreID_CustNum_AmountRemaining_TransAmount_DateTime] ON [dbo].[AR_Transactions]
(
	[Store_ID] ASC,
	[CustNum] ASC,
	[AmountRemaining] ASC,
	[Trans_Amount] ASC,
	[DateTime] ASC
)
INCLUDE([Trans_ID],[Cashier_ID],[Trans_Type],[Invoice_Number],[Station_ID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxAR_TransactionsDateTime]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxAR_TransactionsDateTime] ON [dbo].[AR_Transactions]
(
	[DateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxCC_Trans]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxCC_Trans] ON [dbo].[CC_Trans]
(
	[Store_ID] ASC,
	[CRENumber] ASC,
	[Sub_Invoice_Number] ASC
)
INCLUDE([CashBack]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxExceptionsCashier_ID]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxExceptionsCashier_ID] ON [dbo].[Exceptions]
(
	[Cashier_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxExceptionsException_DateTime]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxExceptionsException_DateTime] ON [dbo].[Exceptions]
(
	[Exception_DateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxExceptionsID]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxExceptionsID] ON [dbo].[Exceptions]
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxExceptionsStoreID]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxExceptionsStoreID] ON [dbo].[Exceptions]
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxGift_Card_Trans]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxGift_Card_Trans] ON [dbo].[Gift_Card_Trans]
(
	[Store_ID] ASC,
	[TransType] ASC
)
INCLUDE([Card_ID],[DateTimeStamp],[Amt],[Invoice_Number]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInventoryDept_IDStore_IDItemNumItemType]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInventoryDept_IDStore_IDItemNumItemType] ON [dbo].[Inventory]
(
	[Dept_ID] ASC,
	[Store_ID] ASC,
	[ItemNum] ASC,
	[ItemType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInventory_Transfers_Serials_In]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInventory_Transfers_Serials_In] ON [dbo].[Inventory_Transfers_Serials_In]
(
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInventory_Transfers_Serials_Out]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInventory_Transfers_Serials_Out] ON [dbo].[Inventory_Transfers_Serials_Out]
(
	[ItemNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxInvoice_ExceptionsInvoice_Number]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_ExceptionsInvoice_Number] ON [dbo].[Invoice_Exceptions]
(
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInvoice_ExceptionsStore_ID]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_ExceptionsStore_ID] ON [dbo].[Invoice_Exceptions]
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInvoice_ItemizedItemNumInvoice_NumberStore_IDPricePerorigPricePerGC_SoldLiabilityDiffItemNameLineDisc]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_ItemizedItemNumInvoice_NumberStore_IDPricePerorigPricePerGC_SoldLiabilityDiffItemNameLineDisc] ON [dbo].[Invoice_Itemized]
(
	[ItemNum] ASC,
	[Invoice_Number] ASC,
	[Store_ID] ASC,
	[PricePer] ASC,
	[origPricePer] ASC,
	[GC_Sold] ASC,
	[Liability] ASC,
	[DiffItemName] ASC,
	[LineDisc] ASC,
	[Quantity] ASC,
	[CostPer] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxInvoice_ItemizedLineDisc]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_ItemizedLineDisc] ON [dbo].[Invoice_Itemized]
(
	[LineDisc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [InvoiceLineDiscIndex]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [InvoiceLineDiscIndex] ON [dbo].[Invoice_Itemized]
(
	[LineDisc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInvoice_OnHoldOnHoldID]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_OnHoldOnHoldID] ON [dbo].[Invoice_OnHold]
(
	[OnHoldID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxInvoice_SubCheck_PaymentsInvoice_Number]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_SubCheck_PaymentsInvoice_Number] ON [dbo].[Invoice_SubCheck_Payments]
(
	[Invoice_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInvoice_SubCheck_PaymentsStore_ID]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_SubCheck_PaymentsStore_ID] ON [dbo].[Invoice_SubCheck_Payments]
(
	[Store_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxInvoice_SubCheck_PaymentsSubCheckNum]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_SubCheck_PaymentsSubCheckNum] ON [dbo].[Invoice_SubCheck_Payments]
(
	[SubCheckNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInvoice_TotalsCashier_ID]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_TotalsCashier_ID] ON [dbo].[Invoice_Totals]
(
	[Cashier_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxInvoice_TotalsCost_Center_Index]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_TotalsCost_Center_Index] ON [dbo].[Invoice_Totals]
(
	[Cost_Center_Index] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInvoice_TotalsCustNum]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_TotalsCustNum] ON [dbo].[Invoice_Totals]
(
	[CustNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxInvoice_TotalsDateTime]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_TotalsDateTime] ON [dbo].[Invoice_Totals]
(
	[DateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idxInvoice_TotalsDiscount]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_TotalsDiscount] ON [dbo].[Invoice_Totals]
(
	[Discount] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxInvoice_TotalsStore_IDStatusDateTimeInvoice_NumberDiscount]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxInvoice_TotalsStore_IDStatusDateTimeInvoice_NumberDiscount] ON [dbo].[Invoice_Totals]
(
	[Store_ID] ASC,
	[Status] ASC,
	[DateTime] ASC,
	[Invoice_Number] ASC,
	[Discount] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [InvoiceDiscountIndex]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [InvoiceDiscountIndex] ON [dbo].[Invoice_Totals]
(
	[Discount] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxModifiersItemNumStoreIDGroupOrIndividual]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxModifiersItemNumStoreIDGroupOrIndividual] ON [dbo].[Modifiers]
(
	[Store_ID] ASC,
	[ItemNum] ASC,
	[Group_Or_Individual] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxMoney_Activity_]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxMoney_Activity_] ON [dbo].[Money_Activity]
(
	[Store_ID] ASC,
	[TransactionNumber] ASC,
	[TransactionType] ASC,
	[Cashier_ID] ASC,
	[DateTime] ASC
)
INCLUDE([PaymentType],[ReferenceNumber],[Amount]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxOrderQueueItems]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxOrderQueueItems] ON [dbo].[OrderQueueItems]
(
	[StoreID] ASC,
	[StationID] ASC,
	[QueueID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxOrderQueueSummary]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxOrderQueueSummary] ON [dbo].[OrderQueueSummary]
(
	[StoreID] ASC,
	[StationID] ASC,
	[QueueID] ASC,
	[DueDateTime] ASC,
	[Accepted] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxScheduleCashierIDStoreIDStartDateTimeEndDateTime]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxScheduleCashierIDStoreIDStartDateTimeEndDateTime] ON [dbo].[Schedule]
(
	[Cashier_ID] ASC,
	[Store_ID] ASC,
	[StartDateTime] ASC,
	[EndDateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idxSetup_TS_ButtonsStoreIDStationIDIdentBtnType]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [idxSetup_TS_ButtonsStoreIDStationIDIdentBtnType] ON [dbo].[Setup_TS_Buttons]
(
	[Store_ID] ASC,
	[Station_ID] ASC,
	[Ident] ASC,
	[BtnType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [SetupTSSchedule]    Script Date: 1/30/2026 5:30:25 PM ******/
CREATE NONCLUSTERED INDEX [SetupTSSchedule] ON [dbo].[Setup_TS_Buttons]
(
	[ScheduleIndex] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AccountingInterfaceSettings] ADD  CONSTRAINT [AccountingInterfaceSettingsDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[AR_Trans_Details] ADD  CONSTRAINT [DF_AR_Trans_Details_Trans_ID_AR_Trans_Details]  DEFAULT ((0)) FOR [Trans_ID]
GO
ALTER TABLE [dbo].[AR_Trans_Details] ADD  CONSTRAINT [DF_AR_Trans_Details_Invoice_Number_AR_Trans_Details]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[AR_Transactions] ADD  CONSTRAINT [DF_AR_Transactions_Trans_ID_AR_Transactions]  DEFAULT ((0)) FOR [Trans_ID]
GO
ALTER TABLE [dbo].[AR_Transactions] ADD  CONSTRAINT [DF_AR_Transactions_Invoice_Number_AR_Transactions]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[AR_Transactions] ADD  DEFAULT ((0)) FOR [AmountRemaining]
GO
ALTER TABLE [dbo].[AR_Transactions] ADD  DEFAULT ((0)) FOR [Canceled_Trans]
GO
ALTER TABLE [dbo].[BackOrders] ADD  CONSTRAINT [DF_BackOrders_Invoice_Number_BackOrders]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[BumpBarRoutes] ADD  CONSTRAINT [BumpBarRoutesDefaultObjectID]  DEFAULT (newid()) FOR [ObjectID]
GO
ALTER TABLE [dbo].[CardPaymentBatches] ADD  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF_CC_Trans_Number_CC_Trans]  DEFAULT ('') FOR [Number]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF_CC_Trans_Approval_CC_Trans]  DEFAULT ('') FOR [Approval]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF_CC_Trans_Reference_CC_Trans]  DEFAULT ('') FOR [Reference]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF_CC_Trans_CRENumber_CC_Trans]  DEFAULT ((0)) FOR [CRENumber]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF_CC_Trans_TroutD_CC_Trans]  DEFAULT ('') FOR [TroutD]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF_CC_Trans_PostAuthReferenceNumber_CC_Trans]  DEFAULT ('') FOR [PostAuthReferenceNumber]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF_CC_Trans_OrderId_CC_Trans]  DEFAULT ('') FOR [OrderId]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF__CC_Trans__Accoun__16644E42]  DEFAULT ((0)) FOR [AccountType]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF__CC_Trans__Langua__1758727B]  DEFAULT ('E') FOR [Language]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF__CC_Trans__Applie__71F1E3A2]  DEFAULT ((0.0)) FOR [AppliedGratuity]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF__CC_Trans__PreAut__08F5448B]  DEFAULT ((0.0)) FOR [PreAuthAmount]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  CONSTRAINT [DF_CC_Trans_Token_CC_Trans]  DEFAULT ('') FOR [Token]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  DEFAULT ((0)) FOR [IsSignatureUploaded]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  DEFAULT ((0)) FOR [ApprovedAmount]
GO
ALTER TABLE [dbo].[CC_Trans] ADD  DEFAULT ((0)) FOR [SurChargeAmount]
GO
ALTER TABLE [dbo].[CH_Trans] ADD  CONSTRAINT [DF_CH_Trans_Trans_Number_CH_Trans]  DEFAULT ((0)) FOR [Trans_Number]
GO
ALTER TABLE [dbo].[CH_Trans] ADD  CONSTRAINT [DF_CH_Trans_TroutD_CH_Trans]  DEFAULT ('') FOR [TroutD]
GO
ALTER TABLE [dbo].[CH_Trans] ADD  CONSTRAINT [DF__CH_Trans__Sub_In__3E3D3572]  DEFAULT ((0)) FOR [Sub_Invoice_Number]
GO
ALTER TABLE [dbo].[Customer] ADD  CONSTRAINT [DF_Customer_First_Name_Customer]  DEFAULT ('') FOR [First_Name]
GO
ALTER TABLE [dbo].[Customer] ADD  CONSTRAINT [DF_Customer_Loyalty_Plan_ID_Customer]  DEFAULT ((0)) FOR [Loyalty_Plan_ID]
GO
ALTER TABLE [dbo].[Customer] ADD  DEFAULT ('') FOR [SecretCode]
GO
ALTER TABLE [dbo].[Customer] ADD  DEFAULT ('') FOR [OnlineUserName]
GO
ALTER TABLE [dbo].[Customer] ADD  CONSTRAINT [DF_Customer_OnlinePassword_Customer]  DEFAULT ('') FOR [OnlinePassword]
GO
ALTER TABLE [dbo].[Customer_Gift_Registry_Items] ADD  CONSTRAINT [DF_Customer_Gift_Registry_Items_Quan_Req_Customer_Gift_Registry_Items]  DEFAULT ((0)) FOR [Quan_Req]
GO
ALTER TABLE [dbo].[Customer_Gift_Registry_Items] ADD  CONSTRAINT [DF_Customer_Gift_Registry_Items_Quan_Purch_Customer_Gift_Registry_Items]  DEFAULT ((0)) FOR [Quan_Purch]
GO
ALTER TABLE [dbo].[Departments] ADD  CONSTRAINT [DF_Departments_SubType_Departments]  DEFAULT ('') FOR [SubType]
GO
ALTER TABLE [dbo].[Departments] ADD  CONSTRAINT [DF__Departmen__BarTa__108B795B]  DEFAULT ((0)) FOR [BarTaxInclusive]
GO
ALTER TABLE [dbo].[Departments] ADD  CONSTRAINT [DF__Departmen__Avail__1837881B]  DEFAULT ((0)) FOR [AvailableOnline]
GO
ALTER TABLE [dbo].[Departments] ADD  DEFAULT (newsequentialid()) FOR [RowID]
GO
ALTER TABLE [dbo].[DVRs] ADD  CONSTRAINT [DVRsDefaultObjectID]  DEFAULT (newid()) FOR [ObjectID]
GO
ALTER TABLE [dbo].[Employee] ADD  CONSTRAINT [DF_Employee_Password_Employee]  DEFAULT ('') FOR [Password]
GO
ALTER TABLE [dbo].[Employee] ADD  CONSTRAINT [DF_Employee_Swipe_ID_Employee]  DEFAULT ('') FOR [Swipe_ID]
GO
ALTER TABLE [dbo].[Employee] ADD  CONSTRAINT [DF_Employee_CDL_Employee]  DEFAULT ('') FOR [CDL]
GO
ALTER TABLE [dbo].[Employee] ADD  DEFAULT ((0)) FOR [Retry_Count]
GO
ALTER TABLE [dbo].[Employee] ADD  DEFAULT ((0)) FOR [EnableMobileInventory]
GO
ALTER TABLE [dbo].[Employee_AdditionalInfo] ADD  DEFAULT ((0)) FOR [ExcludeInPayrollExp]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_R__164452B1]  DEFAULT ((0)) FOR [CFA_REST_OPENTABS]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_R__173876EA]  DEFAULT ((0)) FOR [CFA_REST_TAKEOUT]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_R__182C9B23]  DEFAULT ((0)) FOR [CFA_REST_DELIVERY]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__1920BF5C]  DEFAULT ((0)) FOR [CFA_INVOICE_DELETESENT]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__1A14E395]  DEFAULT ((0)) FOR [CFA_INVEN_VIEW]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__1B0907CE]  DEFAULT ((0)) FOR [CFA_INVEN_VIEWCOST]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__1BFD2C07]  DEFAULT ((0)) FOR [CFA_INVEN_NEGATIVE_INSTANTPOS]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_E__1CF15040]  DEFAULT ((0)) FOR [CFA_ENDTRANS_CASH]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_E__1DE57479]  DEFAULT ((0)) FOR [CFA_ENDTRANS_ACCOUNT]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_R__1ED998B2]  DEFAULT ((0)) FOR [CFA_REST_COMP]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_C__1FCDBCEB]  DEFAULT ((0)) FOR [CFA_CH_FORCE]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_T__20C1E124]  DEFAULT ((0)) FOR [CFA_TS_CONFIG]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_T__21B6055D]  DEFAULT ((0)) FOR [CFA_TRANSFER_SERVER]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_B__4DE98D56]  DEFAULT ((0)) FOR [CFA_BACKUP_DATABASE]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_C__4EDDB18F]  DEFAULT ((0)) FOR [CFA_CREDIT_CARD_SETTLEMENT]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_K__5A4F643B]  DEFAULT ((0)) FOR [CFA_KITCHEN_REPRINT]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_S__5E1FF51F]  DEFAULT ((0)) FOR [CFA_SETUP_RECEIPT_NOTES]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_M__5F141958]  DEFAULT ((0)) FOR [CFA_MANAGE_TIMECLOCK_OWNTIME]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_S__60083D91]  DEFAULT ((0)) FOR [CFA_SETUP_ADD_EMPLOYEES]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_S__60FC61CA]  DEFAULT ((0)) FOR [CFA_SETUP_EDIT_EMPLOYEES]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__61F08603]  DEFAULT ((0)) FOR [CFA_INVENTORY_PROMOTIONS]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__62E4AA3C]  DEFAULT ((0)) FOR [CFA_INVOICE_DISCOUNTS_BELOW_X]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_B__63D8CE75]  DEFAULT ((0)) FOR [CFA_BUYBACKTRADE_ABOVE_SET_AMOUNT]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_R__64CCF2AE]  DEFAULT ((0)) FOR [CFA_REPORTS_VIEW_HISTORICAL_DATA]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__65C116E7]  DEFAULT ((0)) FOR [CFA_INVEN_MISC_FIELD_LOCKDOWN]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_H__5B0E7E4A]  DEFAULT ((0)) FOR [CFA_HH_Create_PO]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_H__5C02A283]  DEFAULT ((0)) FOR [CFA_HH_DSD]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_H__5CF6C6BC]  DEFAULT ((0)) FOR [CFA_HH_DSD_Credit]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_H__5DEAEAF5]  DEFAULT ((0)) FOR [CFA_HH_PO_Receive]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_H__5EDF0F2E]  DEFAULT ((0)) FOR [CFA_HH_Inv_Edit]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_H__5FD33367]  DEFAULT ((0)) FOR [CFA_HH_Inv_Adjust]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_H__60C757A0]  DEFAULT ((0)) FOR [CFA_HH_Inv_Count]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_H__61BB7BD9]  DEFAULT ((0)) FOR [CFA_HH_Setup]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_C__6E2152BE]  DEFAULT ((0)) FOR [CFA_CASHIER_OVERRIDE_LICENSESCAN]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__72E607DB]  DEFAULT ((0)) FOR [CFA_INVEN_DELETE]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_C__031C6FA4]  DEFAULT ((0)) FOR [CFA_CASHIER_MANUALY_ENTER_AGE]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__153B1FDF]  DEFAULT ((0)) FOR [CFA_INVEN_ADD_COUPON]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_I__162F4418]  DEFAULT ((0)) FOR [CFA_INVEN_GLOBALPRICING]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_E__19FFD4FC]  DEFAULT ((0)) FOR [CFA_EMP_SCHEDULE_OVERRIDE]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_L__1BE81D6E]  DEFAULT ((0)) FOR [CFA_LABOR_SCHEDULER]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_N__1A1FD08D]  DEFAULT ((0)) FOR [CFA_NEGATIVE_PRICE_CHANGE]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  CONSTRAINT [DF__Employee___CFA_C__581D0306]  DEFAULT ((0)) FOR [CFA_CUSTOMER_EDIT_CHARGEATCOST]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  DEFAULT ((0)) FOR [CFA_DELETE_CUSTOMER]
GO
ALTER TABLE [dbo].[Employee_PermExceptions] ADD  DEFAULT ((0)) FOR [CFA_RECALL_INVOICE]
GO
ALTER TABLE [dbo].[EmployeeStores] ADD  CONSTRAINT [EmployeeStoresDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[EmployeeStores] ADD  DEFAULT ((0)) FOR [Inactive]
GO
ALTER TABLE [dbo].[End_Of_Day] ADD  CONSTRAINT [DF__End_Of_Da__Actua__1EE485AA]  DEFAULT ((0)) FOR [Actual_C2]
GO
ALTER TABLE [dbo].[End_Of_Day] ADD  CONSTRAINT [DF__End_Of_Da__OverS__1FD8A9E3]  DEFAULT ((0)) FOR [OverShort_C2]
GO
ALTER TABLE [dbo].[Exceptions] ADD  CONSTRAINT [DF_Exceptions_ID_Exceptions]  DEFAULT ((0)) FOR [ID]
GO
ALTER TABLE [dbo].[Exceptions] ADD  CONSTRAINT [DF_Exceptions_Reason_Code_Exceptions]  DEFAULT ('') FOR [Reason_Code]
GO
ALTER TABLE [dbo].[Exceptions] ADD  CONSTRAINT [DF__Exception__RowID__090A5324]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Exchange_AdditionalInfo] ADD  CONSTRAINT [Exchange_AdditionalInfoDefaultID]  DEFAULT ((0)) FOR [ID]
GO
ALTER TABLE [dbo].[GeneralLog] ADD  CONSTRAINT [GeneralLogDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF_Gift_Card_Trans_Card_ID_Gift_Card_Trans]  DEFAULT ('') FOR [Card_ID]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF_Gift_Card_Trans_Invoice_Number_Gift_Card_Trans]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF_Gift_Card_Trans_TroutD_Gift_Card_Trans]  DEFAULT ('') FOR [TroutD]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF_Gift_Card_Trans_Approval_Gift_Card_Trans]  DEFAULT ('') FOR [Approval]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF_Gift_Card_Trans_Reference_Gift_Card_Trans]  DEFAULT ('') FOR [Reference]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF_Gift_Card_Trans_ReceiptText_Gift_Card_Trans]  DEFAULT ('') FOR [ReceiptText]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF__Gift_Card__Vouch__35A7EF71]  DEFAULT ((0)) FOR [VoucherType]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF_Gift_Card_Trans_Responsemessage_Gift_Card_Trans]  DEFAULT ('') FOR [Responsemessage]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  CONSTRAINT [DF__Gift_Card__Check__0524B3A7]  DEFAULT ((0.00)) FOR [CheckRetrunFee]
GO
ALTER TABLE [dbo].[Gift_Card_Trans] ADD  DEFAULT ((0)) FOR [InitiatedByReturn]
GO
ALTER TABLE [dbo].[Gift_Cards] ADD  CONSTRAINT [DF_Gift_Cards_Card_ID_Gift_Cards]  DEFAULT ('') FOR [Card_ID]
GO
ALTER TABLE [dbo].[Groups] ADD  DEFAULT ((0)) FOR [isDeleted]
GO
ALTER TABLE [dbo].[Ingredients_Used] ADD  CONSTRAINT [DF_Ingredients_Used_Quantity_Ingredients_Used]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF_Inventory_Cost_Inventory]  DEFAULT ((0)) FOR [Cost]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF_Inventory_Price_Inventory]  DEFAULT ((0)) FOR [Price]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF_Inventory_Retail_Price_Inventory]  DEFAULT ((0)) FOR [Retail_Price]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF_Inventory_In_Stock_Inventory]  DEFAULT ((0)) FOR [In_Stock]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF_Inventory_Old_InStock_Inventory]  DEFAULT ((0)) FOR [Old_InStock]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF__Inventory__BarTa__2F10007B]  DEFAULT ((0)) FOR [BarTaxInclusive]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF_Inventory_numberOfFreeToppings_Inventory]  DEFAULT ((0)) FOR [numberOfFreeToppings]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF__Inventory__IsDel__592635D8]  DEFAULT ((0)) FOR [IsDeleted]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF_Inventory_QuantityRequired_Inventory]  DEFAULT ((0)) FOR [QuantityRequired]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF__Inventory__Impor__7993056A]  DEFAULT ((0)) FOR [Import_Markup]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF__Inventory__Price__7A8729A3]  DEFAULT ((0)) FOR [PricePerMeasure]
GO
ALTER TABLE [dbo].[Inventory] ADD  CONSTRAINT [DF__Inventory__Avail__192BAC54]  DEFAULT ((0)) FOR [AvailableOnline]
GO
ALTER TABLE [dbo].[Inventory] ADD  DEFAULT ((0)) FOR [DoughnutTax]
GO
ALTER TABLE [dbo].[Inventory] ADD  DEFAULT (newsequentialid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Inventory] ADD  DEFAULT ((0)) FOR [DisableInventoryUpload]
GO
ALTER TABLE [dbo].[Inventory] ADD  DEFAULT ((0)) FOR [InvoiceLimitQty]
GO
ALTER TABLE [dbo].[Inventory] ADD  DEFAULT ((0)) FOR [ItemCategory]
GO
ALTER TABLE [dbo].[Inventory] ADD  DEFAULT ((0)) FOR [IsRestrictedPerInvoice]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [NoWebSales]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [IsPrimaryMatrixItem]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [Priority]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [Rating]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [CustomNumber1]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [CustomNumber2]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [CustomNumber3]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [CustomNumber4]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ((0)) FOR [CustomNumber5]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [CustomText1]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [CustomText2]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [CustomText3]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [CustomText4]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [CustomText5]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [CustomExtendedText1]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [CustomExtendedText2]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [SubDescription1]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [SubDescription2]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] ADD  DEFAULT ('') FOR [SubDescription3]
GO
ALTER TABLE [dbo].[Inventory_Bulk_Info] ADD  CONSTRAINT [DF_Inventory_Bulk_Info_Bulk_Price_Inventory_Bulk_Info]  DEFAULT ((0)) FOR [Bulk_Price]
GO
ALTER TABLE [dbo].[Inventory_Bulk_Info] ADD  CONSTRAINT [DF_Inventory_Bulk_Info_Bulk_Quan_Inventory_Bulk_Info]  DEFAULT ((0)) FOR [Bulk_Quan]
GO
ALTER TABLE [dbo].[Inventory_Commissions] ADD  CONSTRAINT [DF_Inventory_Commissions_Comm_Amt_Inventory_Commissions]  DEFAULT ((0)) FOR [Comm_Amt]
GO
ALTER TABLE [dbo].[Inventory_CostDisc] ADD  CONSTRAINT [DF_Inventory_CostDisc_Amt1_Inventory_CostDisc]  DEFAULT ((0)) FOR [Amt1]
GO
ALTER TABLE [dbo].[Inventory_CostDisc] ADD  CONSTRAINT [DF_Inventory_CostDisc_Amt2_Inventory_CostDisc]  DEFAULT ((0)) FOR [Amt2]
GO
ALTER TABLE [dbo].[Inventory_CostDisc] ADD  CONSTRAINT [DF_Inventory_CostDisc_Amt3_Inventory_CostDisc]  DEFAULT ((0)) FOR [Amt3]
GO
ALTER TABLE [dbo].[Inventory_Coupon] ADD  DEFAULT ((1)) FOR [Coupon_Bonus_MinimumQuantity]
GO
ALTER TABLE [dbo].[Inventory_CustPrices] ADD  CONSTRAINT [DF_Inventory_CustPrices_Price_Inventory_CustPrices]  DEFAULT ((0)) FOR [Price]
GO
ALTER TABLE [dbo].[Inventory_Image] ADD  CONSTRAINT [DF_Inventory_Image_ID]  DEFAULT ((0)) FOR [ID]
GO
ALTER TABLE [dbo].[Inventory_Image] ADD  CONSTRAINT [DF_Inventory_Image_ItemNum]  DEFAULT ('') FOR [ItemNum]
GO
ALTER TABLE [dbo].[Inventory_Image] ADD  CONSTRAINT [DF_Inventory_Image_Store_ID]  DEFAULT ('') FOR [Store_ID]
GO
ALTER TABLE [dbo].[Inventory_Image] ADD  CONSTRAINT [DF_Inventory_Image_Position]  DEFAULT ((0)) FOR [Position]
GO
ALTER TABLE [dbo].[Inventory_Image] ADD  CONSTRAINT [DF_Inventory_Image_ImageLocation]  DEFAULT ('') FOR [ImageLocation]
GO
ALTER TABLE [dbo].[Inventory_In] ADD  CONSTRAINT [DF_Inventory_In_Quantity_Inventory_In]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_In] ADD  CONSTRAINT [DF_Inventory_In_CostPer_Inventory_In]  DEFAULT ((0)) FOR [CostPer]
GO
ALTER TABLE [dbo].[Inventory_In] ADD  CONSTRAINT [DF__Inventory__RowID__23BE4960]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Inventory_Ingredients] ADD  CONSTRAINT [DF_Inventory_Ingredients_Quantity_Inventory_Ingredients]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_MixNMatch_Levels] ADD  CONSTRAINT [DF_Inventory_MixNMatch_Levels_Quantity_Inventory_MixNMatch_Levels]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_OnSale_Info] ADD  CONSTRAINT [DF_Inventory_OnSale_Info_Price_Inventory_OnSale_Info]  DEFAULT ((0)) FOR [Price]
GO
ALTER TABLE [dbo].[Inventory_PendingOrders] ADD  CONSTRAINT [DF_Inventory_PendingOrders_Invoice_Number_Inventory_PendingOrders]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Inventory_Prices] ADD  CONSTRAINT [DF_Inventory_Prices_Price_Inventory_Prices]  DEFAULT ((0)) FOR [Price]
GO
ALTER TABLE [dbo].[Inventory_Rental_Info] ADD  CONSTRAINT [DF__Inventory__RowID__25A691D2]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Inventory_Reorder] ADD  CONSTRAINT [DF_Inventory_Reorder_Cost_Inventory_Reorder]  DEFAULT ((0)) FOR [Cost]
GO
ALTER TABLE [dbo].[Inventory_Reorder] ADD  CONSTRAINT [DF_Inventory_Reorder_In_Stock_Inventory_Reorder]  DEFAULT ((0)) FOR [In_Stock]
GO
ALTER TABLE [dbo].[Inventory_Serial_Incoming] ADD  CONSTRAINT [DF_Inventory_Serial_Incoming_Quantity_Inventory_Serial_Incoming]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_Special] ADD  CONSTRAINT [DF_Inventory_Special_Quantity_Inventory_Special]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_Special] ADD  CONSTRAINT [DF_Inventory_Special_Price_Inventory_Special]  DEFAULT ((0)) FOR [Price]
GO
ALTER TABLE [dbo].[Inventory_TagAlongs] ADD  CONSTRAINT [DF_Inventory_TagAlongs_Quantity_Inventory_TagAlongs]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_Taking] ADD  CONSTRAINT [DF_Inventory_Taking_In_Stock_Inventory_Taking]  DEFAULT ((0)) FOR [In_Stock]
GO
ALTER TABLE [dbo].[Inventory_Taking] ADD  CONSTRAINT [DF_Inventory_Taking_Price_Inventory_Taking]  DEFAULT ((0)) FOR [Price]
GO
ALTER TABLE [dbo].[Inventory_Taking] ADD  CONSTRAINT [DF_Inventory_Taking_Cost_Inventory_Taking]  DEFAULT ((0)) FOR [Cost]
GO
ALTER TABLE [dbo].[Inventory_Transfers_In] ADD  CONSTRAINT [DF_Inventory_Transfers_In_Quantity_Inventory_Transfers_In]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_Transfers_In] ADD  CONSTRAINT [DF_Inventory_Transfers_In_CostPer_Inventory_Transfers_In]  DEFAULT ((0)) FOR [CostPer]
GO
ALTER TABLE [dbo].[Inventory_Transfers_Out] ADD  CONSTRAINT [DF_Inventory_Transfers_Out_Quantity_Inventory_Transfers_Out]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_Transfers_Out] ADD  CONSTRAINT [DF_Inventory_Transfers_Out_CostPer_Inventory_Transfers_Out]  DEFAULT ((0)) FOR [CostPer]
GO
ALTER TABLE [dbo].[Inventory_Transfers_Serials_In] ADD  CONSTRAINT [DF_Inventory_Transfers_Serials_In_Quantity_Inventory_Transfers_Serials_In]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_Transfers_Serials_Out] ADD  CONSTRAINT [DF_Inventory_Transfers_Serials_Out_Quantity_Inventory_Transfers_Serials_Out]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Inventory_Vendors] ADD  CONSTRAINT [DF__Inventory__Lande__7B7B4DDC]  DEFAULT ((0)) FOR [LandedCost]
GO
ALTER TABLE [dbo].[InventoryOrderItems] ADD  CONSTRAINT [InventoryOrderItemsDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[InventoryOrderItems] ADD  CONSTRAINT [DF_InventoryOrderItems_QtyOrdered_InventoryOrderItems]  DEFAULT ((0)) FOR [QtyOrdered]
GO
ALTER TABLE [dbo].[InventoryOrderItems] ADD  CONSTRAINT [DF_InventoryOrderItems_QtyReceived_InventoryOrderItems]  DEFAULT ((0)) FOR [QtyReceived]
GO
ALTER TABLE [dbo].[InventoryOrderItems] ADD  CONSTRAINT [DF_InventoryOrderItems_QtyDamaged_InventoryOrderItems]  DEFAULT ((0)) FOR [QtyDamaged]
GO
ALTER TABLE [dbo].[InventoryOrderItems] ADD  CONSTRAINT [DF_InventoryOrderItems_QtyLost_InventoryOrderItems]  DEFAULT ((0)) FOR [QtyLost]
GO
ALTER TABLE [dbo].[InventoryOrderItems] ADD  CONSTRAINT [DF__Inventory__Statu__546180BB]  DEFAULT ((0)) FOR [Status]
GO
ALTER TABLE [dbo].[InventoryOrderItems] ADD  CONSTRAINT [DF__Inventory__NumPe__6B44E613]  DEFAULT ((0)) FOR [NumPerCase]
GO
ALTER TABLE [dbo].[InventoryOrders] ADD  CONSTRAINT [InventoryOrdersDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[InventoryOrderSerialNumbers] ADD  CONSTRAINT [InventoryOrderSerialNumbersDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Invoice_AccountingExport] ADD  CONSTRAINT [DF_Invoice_AccountingExport_Invoice_Number_Invoice_AccountingExport]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_AccountingExport] ADD  CONSTRAINT [DF_Invoice_AccountingExport_SubType_Invoice_AccountingExport]  DEFAULT ((0)) FOR [SubType]
GO
ALTER TABLE [dbo].[Invoice_Deliveries] ADD  CONSTRAINT [DF_Invoice_Deliveries_Invoice_Number_Invoice_Deliveries]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Exceptions] ADD  CONSTRAINT [DF_Invoice_Exceptions_Invoice_Number_Invoice_Exceptions]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Exceptions] ADD  CONSTRAINT [DF_Invoice_Exceptions_Amount_Invoice_Exceptions]  DEFAULT ((0)) FOR [Amount]
GO
ALTER TABLE [dbo].[Invoice_Exceptions] ADD  CONSTRAINT [DF_Invoice_Exceptions_Quantity_Invoice_Exceptions]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Invoice_Exceptions] ADD  DEFAULT (newsequentialid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Invoice_GasPumpInterface] ADD  CONSTRAINT [DF_Invoice_GasPumpInterface_DollarAmount_Invoice_GasPumpInterface]  DEFAULT ((0)) FOR [DollarAmount]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  CONSTRAINT [DF_Invoice_Itemized_Invoice_Number_Invoice_Itemized]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  CONSTRAINT [DF_Invoice_Itemized_Quantity_Invoice_Itemized]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  CONSTRAINT [DF__Invoice_I__modif__369C13AA]  DEFAULT ((0)) FOR [modifierPriceLock]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  CONSTRAINT [DF_Invoice_Itemized_PricePerBeforeDiscount_Invoice_Itemized]  DEFAULT ((0)) FOR [PricePerBeforeDiscount]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  DEFAULT ((0)) FOR [OrigPriceSetBy]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  DEFAULT ((0)) FOR [PriceChangedBy]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  DEFAULT ((0)) FOR [Kit_Override]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  DEFAULT ((0)) FOR [KitTotal]
GO
ALTER TABLE [dbo].[Invoice_Itemized] ADD  DEFAULT ((0)) FOR [SentToKitchen]
GO
ALTER TABLE [dbo].[Invoice_Itemized_ItemNotes] ADD  CONSTRAINT [DF_Invoice_Itemized_ItemNotes_Invoice_Number_Invoice_Itemized_ItemNotes]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Itemized_Layaway] ADD  CONSTRAINT [DF_Invoice_Itemized_Layaway_Invoice_Number_Invoice_Itemized_Layaway]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Itemized_Return_Details] ADD  CONSTRAINT [DF_Invoice_Itemized_Return_Details_Invoice_Number_Invoice_Itemized_Return_Details]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Itemized_Return_Details] ADD  CONSTRAINT [DF_Invoice_Itemized_Return_Details_Orig_Invoice_Number_Invoice_Itemized_Return_Details]  DEFAULT ((0)) FOR [Orig_Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_OnHold] ADD  CONSTRAINT [DF_Invoice_OnHold_Invoice_Number_Invoice_OnHold]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_OnHold] ADD  CONSTRAINT [DF_Invoice_OnHold_OnHoldID_Invoice_OnHold]  DEFAULT ('') FOR [OnHoldID]
GO
ALTER TABLE [dbo].[Invoice_Serial_Sales] ADD  CONSTRAINT [DF_Invoice_Serial_Sales_Invoice_Number_Invoice_Serial_Sales]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Signatures] ADD  CONSTRAINT [DF_Invoice_Signatures_Invoice_Number_Invoice_Signatures]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_StateChanges] ADD  CONSTRAINT [DF_Invoice_StateChanges_Invoice_Number_Invoice_StateChanges]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_SubCheck] ADD  CONSTRAINT [DF_Invoice_SubCheck_Invoice_Number_Invoice_SubCheck]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_SubCheck] ADD  DEFAULT ((0)) FOR [Donation_Amount]
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Items] ADD  CONSTRAINT [DF_Invoice_SubCheck_Items_Invoice_Number_Invoice_SubCheck_Items]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Items] ADD  CONSTRAINT [DF_Invoice_SubCheck_Items_Quantity_Invoice_SubCheck_Items]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Payments] ADD  CONSTRAINT [DF_Invoice_SubCheck_Payments_Invoice_Number_Invoice_SubCheck_Payments]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Payments] ADD  CONSTRAINT [DF_Invoice_SubCheck_Payments_InvoiceRefNum_Invoice_SubCheck_Payments]  DEFAULT ((0)) FOR [InvoiceRefNum]
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Payments] ADD  CONSTRAINT [DF__Invoice_S__RowID__5090EFD7]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Invoice_Totals] ADD  CONSTRAINT [DF_Invoice_Totals_Invoice_Number_Invoice_Totals]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Totals] ADD  CONSTRAINT [DF__Invoice_T__Amt_C__40257DE4]  DEFAULT ((0)) FOR [Amt_CA_Sec_Tendered]
GO
ALTER TABLE [dbo].[Invoice_Totals] ADD  CONSTRAINT [DF_Invoice_Totals_OrderSource_Invoice_Totals]  DEFAULT ((0)) FOR [OrderSource]
GO
ALTER TABLE [dbo].[Invoice_Totals] ADD  DEFAULT ((0)) FOR [Donation_Amount]
GO
ALTER TABLE [dbo].[Invoice_Totals] ADD  DEFAULT ((0)) FOR [Total_UndiscountedSale]
GO
ALTER TABLE [dbo].[Invoice_Totals] ADD  DEFAULT ((0)) FOR [Split_Check_Type]
GO
ALTER TABLE [dbo].[Invoice_Totals] ADD  DEFAULT ((0)) FOR [AgeVerificationMethod]
GO
ALTER TABLE [dbo].[Invoice_Totals] ADD  DEFAULT ((0)) FOR [AgeVerification]
GO
ALTER TABLE [dbo].[Invoice_Totals_Notes] ADD  CONSTRAINT [DF_Invoice_Totals_Notes_Invoice_Number_Invoice_Totals_Notes]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Totals_Person_Mapping] ADD  CONSTRAINT [DF_Invoice_Totals_Person_Mapping_Invoice_Number_Invoice_Totals_Person_Mapping]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Totals_ShipTos] ADD  CONSTRAINT [DF_Invoice_Totals_ShipTos_Invoice_Number_Invoice_Totals_ShipTos]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[Invoice_Totals_TaxExempt] ADD  CONSTRAINT [DF_Invoice_Totals_TaxExempt_Invoice_Number_Invoice_Totals_TaxExempt]  DEFAULT ((0)) FOR [Invoice_Number]
GO
ALTER TABLE [dbo].[JobCode_Payroll_Setting] ADD  CONSTRAINT [DF_JobCode_Payroll_Setting_id_JobCode_Payroll_Setting]  DEFAULT (newid()) FOR [id]
GO
ALTER TABLE [dbo].[JobcodePermissions] ADD  CONSTRAINT [JobcodePermissionsDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[LabelProduction] ADD  CONSTRAINT [Default_LabelProduction_RowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Loyalty_Items] ADD  CONSTRAINT [DF__Loyalty_I__Child__02284B6B]  DEFAULT ((0)) FOR [ChildItemsFree]
GO
ALTER TABLE [dbo].[Loyalty_Plans] ADD  CONSTRAINT [DF_Loyalty_Plans_Loyalty_Plan_ID_Loyalty_Plans]  DEFAULT ((0)) FOR [Loyalty_Plan_ID]
GO
ALTER TABLE [dbo].[Loyalty_Plans_Items] ADD  CONSTRAINT [DF_Loyalty_Plans_Items_Loyalty_Plan_ID_Loyalty_Plans_Items]  DEFAULT ((0)) FOR [Loyalty_Plan_ID]
GO
ALTER TABLE [dbo].[Mobile_PO_Summary] ADD  DEFAULT ((0)) FOR [IsChanged]
GO
ALTER TABLE [dbo].[MobileApp_Inventory] ADD  DEFAULT ((0)) FOR [CostPer]
GO
ALTER TABLE [dbo].[MobileApp_Inventory] ADD  DEFAULT ((0)) FOR [Case_Cost]
GO
ALTER TABLE [dbo].[Modifier_Groups_Details] ADD  CONSTRAINT [DF_Modifier_Groups_Details_Quantity_Modifier_Groups_Details]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[Modifier_Groups_Details] ADD  CONSTRAINT [DF_Modifier_Groups_Details_Price_Modifier_Groups_Details]  DEFAULT ((0)) FOR [Price]
GO
ALTER TABLE [dbo].[Modifiers] ADD  CONSTRAINT [DF__Modifiers__RowID__573DED66]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Money_Activity] ADD  CONSTRAINT [DF_Money_Activity_Index_Money_Activity]  DEFAULT ((0)) FOR [Index]
GO
ALTER TABLE [dbo].[Money_Activity] ADD  CONSTRAINT [DF_Money_Activity_TransactionNumber_Money_Activity]  DEFAULT ((0)) FOR [TransactionNumber]
GO
ALTER TABLE [dbo].[OrderQueueItems] ADD  CONSTRAINT [OrderQueueItemsDefaultObjectID]  DEFAULT (newid()) FOR [ObjectID]
GO
ALTER TABLE [dbo].[OrderQueueItems] ADD  CONSTRAINT [DF_OrderQueueItems_Quantity_OrderQueueItems]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[OrderQueueSummary] ADD  CONSTRAINT [OrderQueueSummaryDefaultQueueID]  DEFAULT (newid()) FOR [QueueID]
GO
ALTER TABLE [dbo].[PackageItems] ADD  CONSTRAINT [PackageItemsDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[PackageItems] ADD  CONSTRAINT [DF_PackageItems_QtyShipped_PackageItems]  DEFAULT ((0)) FOR [QtyShipped]
GO
ALTER TABLE [dbo].[PackageItems] ADD  CONSTRAINT [DF_PackageItems_QtyReceived_PackageItems]  DEFAULT ((0)) FOR [QtyReceived]
GO
ALTER TABLE [dbo].[PackageItems] ADD  CONSTRAINT [DF_PackageItems_QtyDamaged_PackageItems]  DEFAULT ((0)) FOR [QtyDamaged]
GO
ALTER TABLE [dbo].[PackageItems] ADD  CONSTRAINT [DF_PackageItems_QtyLost_PackageItems]  DEFAULT ((0)) FOR [QtyLost]
GO
ALTER TABLE [dbo].[PackageItems] ADD  CONSTRAINT [DF_PackageItems_Cost_PackageItems]  DEFAULT ((0)) FOR [Cost]
GO
ALTER TABLE [dbo].[Packages] ADD  CONSTRAINT [PackagesDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Payment_Processing_Config] ADD  CONSTRAINT [DF_Payment_Processing_Config_Password_Payment_Processing_Config]  DEFAULT ('') FOR [Password]
GO
ALTER TABLE [dbo].[Payment_Processing_Config] ADD  CONSTRAINT [DF_Payment_Processing_Config_ProcessingCompany_Payment_Processing_Config]  DEFAULT ('') FOR [ProcessingCompany]
GO
ALTER TABLE [dbo].[Payment_Processing_Config] ADD  CONSTRAINT [DF_Payment_Processing_Config_SecondaryProcessingCompany_Payment_Processing_Config]  DEFAULT ('') FOR [SecondaryProcessingCompany]
GO
ALTER TABLE [dbo].[Payment_Processing_Config] ADD  DEFAULT ('') FOR [SecondaryMerchantNumber]
GO
ALTER TABLE [dbo].[Payment_Processing_Config] ADD  DEFAULT ((1)) FOR [TimeoutForBackGroundChecking]
GO
ALTER TABLE [dbo].[Payment_Processing_Config] ADD  DEFAULT ((0)) FOR [CaptureType]
GO
ALTER TABLE [dbo].[Payment_Processing_Config] ADD  DEFAULT ((0)) FOR [BlindRefund]
GO
ALTER TABLE [dbo].[Payment_Processing_Config] ADD  DEFAULT ((0)) FOR [PinPadConnectionType]
GO
ALTER TABLE [dbo].[Permissions] ADD  DEFAULT ('') FOR [ShortDescription]
GO
ALTER TABLE [dbo].[Permissions] ADD  DEFAULT ('') FOR [LongDescription]
GO
ALTER TABLE [dbo].[PickList] ADD  CONSTRAINT [PickListDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[PO_Details_CostDisc] ADD  CONSTRAINT [DF_PO_Details_CostDisc_Amt1_PO_Details_CostDisc]  DEFAULT ((0)) FOR [Amt1]
GO
ALTER TABLE [dbo].[PO_Details_CostDisc] ADD  CONSTRAINT [DF_PO_Details_CostDisc_Amt2_PO_Details_CostDisc]  DEFAULT ((0)) FOR [Amt2]
GO
ALTER TABLE [dbo].[PO_Details_CostDisc] ADD  CONSTRAINT [DF_PO_Details_CostDisc_Amt3_PO_Details_CostDisc]  DEFAULT ((0)) FOR [Amt3]
GO
ALTER TABLE [dbo].[PO_Details_StoreListing] ADD  CONSTRAINT [DF_PO_Details_StoreListing_Quan_Ordered_PO_Details_StoreListing]  DEFAULT ((0)) FOR [Quan_Ordered]
GO
ALTER TABLE [dbo].[PO_Details_StoreListing] ADD  CONSTRAINT [DF_PO_Details_StoreListing_Quan_Received_PO_Details_StoreListing]  DEFAULT ((0)) FOR [Quan_Received]
GO
ALTER TABLE [dbo].[PO_Details_StoreListing] ADD  CONSTRAINT [DF_PO_Details_StoreListing_Quan_Damaged_PO_Details_StoreListing]  DEFAULT ((0)) FOR [Quan_Damaged]
GO
ALTER TABLE [dbo].[PO_Details_StoreListing] ADD  CONSTRAINT [DF_PO_Details_StoreListing_Current_Batch_Quan_PO_Details_StoreListing]  DEFAULT ((0)) FOR [Current_Batch_Quan]
GO
ALTER TABLE [dbo].[PO_Summary_Accounting_Transaction] ADD  CONSTRAINT [DF_PO_Summary_Accounting_Transaction_Tran_Type_PO_Summary_Accounting_Transaction]  DEFAULT ((0)) FOR [Tran_Type]
GO
ALTER TABLE [dbo].[PriceBatch] ADD  CONSTRAINT [PriceBatchDefaultBatchID]  DEFAULT (newid()) FOR [BatchID]
GO
ALTER TABLE [dbo].[PriceBatchDetail] ADD  CONSTRAINT [PriceBatchDetailDefaultBatchID]  DEFAULT (newid()) FOR [BatchID]
GO
ALTER TABLE [dbo].[PriceBatchDetail] ADD  CONSTRAINT [PriceBatchDetailDefaultDetailID]  DEFAULT (newid()) FOR [DetailID]
GO
ALTER TABLE [dbo].[PriceBatchDetail] ADD  CONSTRAINT [DF_PriceBatchDetail_Amount_PriceBatchDetail]  DEFAULT ((0)) FOR [Amount]
GO
ALTER TABLE [dbo].[PriceBatchDetail] ADD  CONSTRAINT [DF_PriceBatchDetail_Quantity_PriceBatchDetail]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[PriceBatchStoreDetail] ADD  CONSTRAINT [PriceBatchStoreDetailDefaultBatchID]  DEFAULT (newid()) FOR [BatchID]
GO
ALTER TABLE [dbo].[PriceBatchStoreDetail] ADD  CONSTRAINT [PriceBatchStoreDetailDefaultDetailID]  DEFAULT (newid()) FOR [DetailID]
GO
ALTER TABLE [dbo].[PriceBatchStoreDetail] ADD  CONSTRAINT [DF_PriceBatchStoreDetail_Amount_PriceBatchStoreDetail]  DEFAULT ((0)) FOR [Amount]
GO
ALTER TABLE [dbo].[PriceBatchStoreDetail] ADD  CONSTRAINT [DF_PriceBatchStoreDetail_Quantity_PriceBatchStoreDetail]  DEFAULT ((0)) FOR [Quantity]
GO
ALTER TABLE [dbo].[PriceBatchStores] ADD  CONSTRAINT [PriceBatchStoresDefaultBatchID]  DEFAULT (newid()) FOR [BatchID]
GO
ALTER TABLE [dbo].[Reports_Setup] ADD  DEFAULT ((0)) FOR [Report_HideDisabled]
GO
ALTER TABLE [dbo].[Schedule] ADD  CONSTRAINT [DF__Schedule__RowID__1AF3F935]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Schedule_Breaks] ADD  CONSTRAINT [Schedule_BreaksDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__AllowStan__7C4F7684]  DEFAULT ((1)) FOR [AllowStandaloneModifiers]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__NumStoreC__0AF29B96]  DEFAULT ((1)) FOR [NumStoreCreditReceipts]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__LayawayFo__0BE6BFCF]  DEFAULT ((0)) FOR [LayawayForceDepositMinimum]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__HideInvoi__0CDAE408]  DEFAULT ((0)) FOR [HideInvoiceQuantityTextbox]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__HideInvoi__0DCF0841]  DEFAULT ((0)) FOR [HideInvoiceChangeQuantityButton]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__ChargeFor__0EC32C7A]  DEFAULT ((0)) FOR [ChargeForToppingSubstitutions]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__CheaperTo__041093DD]  DEFAULT ((0)) FOR [CheaperToppingsFree]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__LineDisco__08D548FA]  DEFAULT ((0)) FOR [LineDiscountPromptType]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__Batch_Siz__125EB334]  DEFAULT ((0)) FOR [Batch_Size]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__PrintPaid__3A6CA48E]  DEFAULT ((0)) FOR [PrintPaidStatusInKitchenReceipt]
GO
ALTER TABLE [dbo].[Setup] ADD  CONSTRAINT [DF__Setup__WhenRemov__3B60C8C7]  DEFAULT ((0)) FOR [WhenRemovingADefaultTopping]
GO
ALTER TABLE [dbo].[Setup] ADD  DEFAULT ((0)) FOR [DeliveryDirectionsProvider]
GO
ALTER TABLE [dbo].[Setup] ADD  DEFAULT ((0)) FOR [Round_Cash_Transactions]
GO
ALTER TABLE [dbo].[Setup] ADD  DEFAULT ('') FOR [Phone_1]
GO
ALTER TABLE [dbo].[Setup] ADD  DEFAULT ((0)) FOR [payroll_export_type]
GO
ALTER TABLE [dbo].[Setup_TS_Buttons] ADD  CONSTRAINT [DF__Setup_TS___RowID__5555A4F4]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Setup_TS_Buttons] ADD  DEFAULT ((0)) FOR [HideCaption]
GO
ALTER TABLE [dbo].[SetupRestaurantCourses] ADD  CONSTRAINT [SetupRestaurantCoursesDefaultCourseID]  DEFAULT (newid()) FOR [CourseID]
GO
ALTER TABLE [dbo].[SetupRestaurantCourses] ADD  CONSTRAINT [DF__SetupRest__Cours__01342732]  DEFAULT ((0)) FOR [CourseOrderNumber]
GO
ALTER TABLE [dbo].[SetupRestaurantCoursesDepartments] ADD  CONSTRAINT [SetupRestaurantCoursesDepartmentsDefaultCourseID]  DEFAULT (newid()) FOR [CourseID]
GO
ALTER TABLE [dbo].[ShiftsMediaTypes] ADD  DEFAULT ((1)) FOR [DrawerDeposit]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ('') FOR [CDL]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__TABLE___03F0984C]  DEFAULT ((0)) FOR [TABLE_HIDE_OPENTABS]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__TABLE___04E4BC85]  DEFAULT ((0)) FOR [TABLE_HIDE_TAKEOUT]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__TABLE___05D8E0BE]  DEFAULT ((0)) FOR [TABLE_HIDE_DELIVERY]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__TABLE___06CD04F7]  DEFAULT ((0)) FOR [TABLE_HIDE_QUICKTAB]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__Disabl__07C12930]  DEFAULT ((0)) FOR [DisableTimeBasedPricing]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__PrintS__08B54D69]  DEFAULT ((0)) FOR [PrintSuggestedTip]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__DVRCam__70FDBF69]  DEFAULT ((0)) FOR [DVRCameraID]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__Prompt__0D99FE17]  DEFAULT ((0)) FOR [PromptIdentifier]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__Commis__0EAE1DE1]  DEFAULT ((0)) FOR [CommissionPrompt]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__C2_Cou__1DF06171]  DEFAULT ((0)) FOR [C2_Count]
GO
ALTER TABLE [dbo].[Stations] ADD  CONSTRAINT [DF__Stations__DeliSc__310335E5]  DEFAULT ((0)) FOR [DeliScaleType]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ((0)) FOR [WirelessPayment]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ((0)) FOR [WirelessPaymentIPPort]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ((0)) FOR [KitchenPrinter_FontSize]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ((0)) FOR [PinPad_MSRTrack]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ((0)) FOR [CustomerRequiredForDelivery]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ((0)) FOR [End_Trans_Order]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ((0)) FOR [Restaurant_InvGrid_TxtSize]
GO
ALTER TABLE [dbo].[Stations] ADD  DEFAULT ((0)) FOR [Use_DefaultSalesperson]
GO
ALTER TABLE [dbo].[Stations_CD] ADD  DEFAULT ('') FOR [CDL]
GO
ALTER TABLE [dbo].[Tax_Rate] ADD  DEFAULT ((0)) FOR [Doughnut_Tax_Rate]
GO
ALTER TABLE [dbo].[Tax_Rate] ADD  DEFAULT ((0)) FOR [Doughnut_Tax_Rate_Threshold]
GO
ALTER TABLE [dbo].[Time_Clock] ADD  CONSTRAINT [DF__Time_Cloc__NonAp__09C96D33]  DEFAULT ((0)) FOR [NonAppliedGratuityCashTips]
GO
ALTER TABLE [dbo].[Time_Clock] ADD  CONSTRAINT [DF__Time_Cloc__Total__2759D01A]  DEFAULT ((0.00)) FOR [Total_DC_Sales]
GO
ALTER TABLE [dbo].[Time_Clock] ADD  CONSTRAINT [DF__Time_Cloc__Total__284DF453]  DEFAULT ((0.00)) FOR [Total_FS_Sales]
GO
ALTER TABLE [dbo].[Time_Clock] ADD  CONSTRAINT [DF__Time_Cloc__Total__44EA3301]  DEFAULT ((0)) FOR [Total_Cash_Layaway_Payments]
GO
ALTER TABLE [dbo].[Time_Clock] ADD  CONSTRAINT [DF__Time_Cloc__Drawe__5911273F]  DEFAULT ((0)) FOR [Drawer_End_SecCurr]
GO
ALTER TABLE [dbo].[Time_Clock] ADD  CONSTRAINT [DF__Time_Cloc__Total__5A054B78]  DEFAULT ((0)) FOR [Total_SecCurr_Sales]
GO
ALTER TABLE [dbo].[Time_Clock] ADD  CONSTRAINT [DF__Time_Cloc__Credi__5AF96FB1]  DEFAULT ((0)) FOR [Credit_Tips_Withheld]
GO
ALTER TABLE [dbo].[Time_Clock] ADD  DEFAULT ((0.00)) FOR [Total_EBTCashBenefit_Sales]
GO
ALTER TABLE [dbo].[Time_Clock_Breaks] ADD  CONSTRAINT [Time_Clock_BreaksDefaultGUIDident]  DEFAULT (newid()) FOR [GUIDident]
GO
ALTER TABLE [dbo].[Timesheet_Accounting_Transaction] ADD  CONSTRAINT [DF__Timesheet___Type__2EFAF1E2]  DEFAULT ((0)) FOR [Type]
GO
ALTER TABLE [dbo].[Timesheet_Accounting_Transaction] ADD  DEFAULT ((0)) FOR [SeqNo]
GO
ALTER TABLE [dbo].[User_Defined] ADD  CONSTRAINT [DF_User_Defined_Type_User_Defined]  DEFAULT ('') FOR [Type]
GO
ALTER TABLE [dbo].[User_Defined] ADD  CONSTRAINT [DF__User_Defi__RowID__33008CF0]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[Vendor_Accounting_Transaction] ADD  DEFAULT ('') FOR [Vendor_Number]
GO
ALTER TABLE [dbo].[Virtual_Pole_Display_Ads] ADD  CONSTRAINT [Virtual_Pole_Display_AdsDefaultRowID]  DEFAULT (newid()) FOR [RowID]
GO
ALTER TABLE [dbo].[AR_Trans_Details]  WITH CHECK ADD  CONSTRAINT [fkAR_Trans_Details] FOREIGN KEY([Store_ID], [PID])
REFERENCES [dbo].[AR_Transactions] ([Store_ID], [Trans_ID])
GO
ALTER TABLE [dbo].[AR_Trans_Details] CHECK CONSTRAINT [fkAR_Trans_Details]
GO
ALTER TABLE [dbo].[BumpBars]  WITH CHECK ADD  CONSTRAINT [fkBumpBars] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[BumpBars] CHECK CONSTRAINT [fkBumpBars]
GO
ALTER TABLE [dbo].[Cost_Centers]  WITH CHECK ADD  CONSTRAINT [fkCost_Centers] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Cost_Centers] CHECK CONSTRAINT [fkCost_Centers]
GO
ALTER TABLE [dbo].[Coupon_Layout]  WITH CHECK ADD  CONSTRAINT [fkCoupon_Layout] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Coupon_Layout] CHECK CONSTRAINT [fkCoupon_Layout]
GO
ALTER TABLE [dbo].[Customer_Authorized]  WITH CHECK ADD  CONSTRAINT [fkCustomer_Authorized] FOREIGN KEY([CustNum])
REFERENCES [dbo].[Customer] ([CustNum])
GO
ALTER TABLE [dbo].[Customer_Authorized] CHECK CONSTRAINT [fkCustomer_Authorized]
GO
ALTER TABLE [dbo].[Customer_Auto]  WITH CHECK ADD  CONSTRAINT [fkCustomer_Auto] FOREIGN KEY([CustNum])
REFERENCES [dbo].[Customer] ([CustNum])
GO
ALTER TABLE [dbo].[Customer_Auto] CHECK CONSTRAINT [fkCustomer_Auto]
GO
ALTER TABLE [dbo].[Customer_Events]  WITH CHECK ADD  CONSTRAINT [fkCustomer_Events] FOREIGN KEY([CustNum])
REFERENCES [dbo].[Customer] ([CustNum])
GO
ALTER TABLE [dbo].[Customer_Events] CHECK CONSTRAINT [fkCustomer_Events]
GO
ALTER TABLE [dbo].[Customer_Gift_Registry]  WITH CHECK ADD  CONSTRAINT [fkCustomer_Gift_Registry] FOREIGN KEY([CustNum])
REFERENCES [dbo].[Customer] ([CustNum])
GO
ALTER TABLE [dbo].[Customer_Gift_Registry] CHECK CONSTRAINT [fkCustomer_Gift_Registry]
GO
ALTER TABLE [dbo].[Customer_Gift_Registry_Items]  WITH CHECK ADD  CONSTRAINT [fkCustomer_Gift_Registry_ItemsRegistry_ID] FOREIGN KEY([Registry_ID])
REFERENCES [dbo].[Customer_Gift_Registry] ([Registry_ID])
GO
ALTER TABLE [dbo].[Customer_Gift_Registry_Items] CHECK CONSTRAINT [fkCustomer_Gift_Registry_ItemsRegistry_ID]
GO
ALTER TABLE [dbo].[Customer_Notes]  WITH CHECK ADD  CONSTRAINT [fkCustomer_Notes] FOREIGN KEY([CustNum])
REFERENCES [dbo].[Customer] ([CustNum])
GO
ALTER TABLE [dbo].[Customer_Notes] CHECK CONSTRAINT [fkCustomer_Notes]
GO
ALTER TABLE [dbo].[Customer_Properties]  WITH CHECK ADD  CONSTRAINT [fkCustomer_PropertiesCustomer] FOREIGN KEY([CustNum])
REFERENCES [dbo].[Customer] ([CustNum])
GO
ALTER TABLE [dbo].[Customer_Properties] CHECK CONSTRAINT [fkCustomer_PropertiesCustomer]
GO
ALTER TABLE [dbo].[Customer_ShipTos]  WITH CHECK ADD  CONSTRAINT [fkCustomer_ShipTos] FOREIGN KEY([CustNum])
REFERENCES [dbo].[Customer] ([CustNum])
GO
ALTER TABLE [dbo].[Customer_ShipTos] CHECK CONSTRAINT [fkCustomer_ShipTos]
GO
ALTER TABLE [dbo].[Customer_Swipes]  WITH CHECK ADD  CONSTRAINT [fkCustomer_Swipes] FOREIGN KEY([CustNum])
REFERENCES [dbo].[Customer] ([CustNum])
GO
ALTER TABLE [dbo].[Customer_Swipes] CHECK CONSTRAINT [fkCustomer_Swipes]
GO
ALTER TABLE [dbo].[Departments]  WITH CHECK ADD  CONSTRAINT [fkDepartments] FOREIGN KEY([Store_ID], [SubType])
REFERENCES [dbo].[Categories] ([Store_ID], [Cat_ID])
GO
ALTER TABLE [dbo].[Departments] CHECK CONSTRAINT [fkDepartments]
GO
ALTER TABLE [dbo].[Donation_Itemized]  WITH CHECK ADD  CONSTRAINT [fkDonation_Itemized] FOREIGN KEY([Store_ID], [Donation_Number])
REFERENCES [dbo].[Donation_Totals] ([Store_ID], [Donation_Number])
GO
ALTER TABLE [dbo].[Donation_Itemized] CHECK CONSTRAINT [fkDonation_Itemized]
GO
ALTER TABLE [dbo].[Employee_JobCode]  WITH CHECK ADD  CONSTRAINT [fkEmployee_JobCodeEmployee] FOREIGN KEY([Cashier_ID])
REFERENCES [dbo].[Employee] ([Cashier_ID])
GO
ALTER TABLE [dbo].[Employee_JobCode] CHECK CONSTRAINT [fkEmployee_JobCodeEmployee]
GO
ALTER TABLE [dbo].[Employee_JobCode]  WITH CHECK ADD  CONSTRAINT [fkEmployee_JobCodeJobCode] FOREIGN KEY([JobCodeID])
REFERENCES [dbo].[JobCode] ([JobCodeID])
GO
ALTER TABLE [dbo].[Employee_JobCode] CHECK CONSTRAINT [fkEmployee_JobCodeJobCode]
GO
ALTER TABLE [dbo].[Employee_PermExceptions]  WITH CHECK ADD  CONSTRAINT [fkEmployee_PermExceptions] FOREIGN KEY([Cashier_ID])
REFERENCES [dbo].[Employee] ([Cashier_ID])
GO
ALTER TABLE [dbo].[Employee_PermExceptions] CHECK CONSTRAINT [fkEmployee_PermExceptions]
GO
ALTER TABLE [dbo].[Friendly_Printers]  WITH CHECK ADD  CONSTRAINT [fkFriendly_Printers] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Friendly_Printers] CHECK CONSTRAINT [fkFriendly_Printers]
GO
ALTER TABLE [dbo].[Groups_Dimensions]  WITH CHECK ADD  CONSTRAINT [fkGroups_Dimensions] FOREIGN KEY([Store_ID], [Group_ID])
REFERENCES [dbo].[Groups] ([Store_ID], [Group_ID])
GO
ALTER TABLE [dbo].[Groups_Dimensions] CHECK CONSTRAINT [fkGroups_Dimensions]
GO
ALTER TABLE [dbo].[Inventory]  WITH CHECK ADD  CONSTRAINT [fkInventoryDepartments] FOREIGN KEY([Store_ID], [Dept_ID])
REFERENCES [dbo].[Departments] ([Store_ID], [Dept_ID])
GO
ALTER TABLE [dbo].[Inventory] CHECK CONSTRAINT [fkInventoryDepartments]
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo]  WITH CHECK ADD  CONSTRAINT [fkInventory_AdditionalInfoInventory] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_AdditionalInfo] CHECK CONSTRAINT [fkInventory_AdditionalInfoInventory]
GO
ALTER TABLE [dbo].[Inventory_Bulk_Info]  WITH CHECK ADD  CONSTRAINT [fkInventory_Bulk_Info] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Bulk_Info] CHECK CONSTRAINT [fkInventory_Bulk_Info]
GO
ALTER TABLE [dbo].[Inventory_BumpBarSettings]  WITH CHECK ADD  CONSTRAINT [fkInventory_BumpBarSettings] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_BumpBarSettings] CHECK CONSTRAINT [fkInventory_BumpBarSettings]
GO
ALTER TABLE [dbo].[Inventory_Commissions]  WITH CHECK ADD  CONSTRAINT [fkInventory_Commissions] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Commissions] CHECK CONSTRAINT [fkInventory_Commissions]
GO
ALTER TABLE [dbo].[Inventory_Consignment]  WITH CHECK ADD  CONSTRAINT [fkInventory_Consignment] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Consignment] CHECK CONSTRAINT [fkInventory_Consignment]
GO
ALTER TABLE [dbo].[Inventory_CostDisc]  WITH CHECK ADD  CONSTRAINT [fkInventory_CostDisc] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_CostDisc] CHECK CONSTRAINT [fkInventory_CostDisc]
GO
ALTER TABLE [dbo].[Inventory_Coupon]  WITH CHECK ADD  CONSTRAINT [fkInventory_Coupon] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Coupon] CHECK CONSTRAINT [fkInventory_Coupon]
GO
ALTER TABLE [dbo].[Inventory_Coupon_Rules]  WITH CHECK ADD  CONSTRAINT [fkInventory_Coupon_Rules] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Coupon_Rules] CHECK CONSTRAINT [fkInventory_Coupon_Rules]
GO
ALTER TABLE [dbo].[Inventory_CustPrices]  WITH CHECK ADD  CONSTRAINT [fkInventory_CustPricesInventory] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_CustPrices] CHECK CONSTRAINT [fkInventory_CustPricesInventory]
GO
ALTER TABLE [dbo].[Inventory_DiscLevels]  WITH CHECK ADD  CONSTRAINT [fkInventory_DiscLevels] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_DiscLevels] CHECK CONSTRAINT [fkInventory_DiscLevels]
GO
ALTER TABLE [dbo].[Inventory_Ingredients]  WITH CHECK ADD  CONSTRAINT [fkInventory_Ingredients] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Ingredients] CHECK CONSTRAINT [fkInventory_Ingredients]
GO
ALTER TABLE [dbo].[Inventory_MixNMatch_Levels]  WITH CHECK ADD  CONSTRAINT [fkInventory_MixNMatch_Levels] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_MixNMatch_Levels] CHECK CONSTRAINT [fkInventory_MixNMatch_Levels]
GO
ALTER TABLE [dbo].[Inventory_Notes]  WITH CHECK ADD  CONSTRAINT [fkInventory_Notes] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Notes] CHECK CONSTRAINT [fkInventory_Notes]
GO
ALTER TABLE [dbo].[Inventory_OnSale_Info]  WITH CHECK ADD  CONSTRAINT [fkInventory_OnSale_Info] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_OnSale_Info] CHECK CONSTRAINT [fkInventory_OnSale_Info]
GO
ALTER TABLE [dbo].[Inventory_PendingOrders]  WITH CHECK ADD  CONSTRAINT [fkInventory_PendingOrders] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_PendingOrders] CHECK CONSTRAINT [fkInventory_PendingOrders]
GO
ALTER TABLE [dbo].[Inventory_Prices]  WITH CHECK ADD  CONSTRAINT [fkInventory_Prices] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Prices] CHECK CONSTRAINT [fkInventory_Prices]
GO
ALTER TABLE [dbo].[Inventory_Properties]  WITH CHECK ADD  CONSTRAINT [fkInventory_PropertiesInventory] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Properties] CHECK CONSTRAINT [fkInventory_PropertiesInventory]
GO
ALTER TABLE [dbo].[Inventory_Remote]  WITH CHECK ADD  CONSTRAINT [fkInventory_Remote] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Remote] CHECK CONSTRAINT [fkInventory_Remote]
GO
ALTER TABLE [dbo].[Inventory_Reorder]  WITH CHECK ADD  CONSTRAINT [fkInventory_Reorder] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Reorder] CHECK CONSTRAINT [fkInventory_Reorder]
GO
ALTER TABLE [dbo].[Inventory_Serial_Incoming]  WITH CHECK ADD  CONSTRAINT [fkInventory_Serial_Incoming] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Serial_Incoming] CHECK CONSTRAINT [fkInventory_Serial_Incoming]
GO
ALTER TABLE [dbo].[Inventory_SKUS]  WITH CHECK ADD  CONSTRAINT [fkInventory_SKUS] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_SKUS] CHECK CONSTRAINT [fkInventory_SKUS]
GO
ALTER TABLE [dbo].[Inventory_Special]  WITH CHECK ADD  CONSTRAINT [fkInventory_Special] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Special] CHECK CONSTRAINT [fkInventory_Special]
GO
ALTER TABLE [dbo].[Inventory_TagAlongs]  WITH CHECK ADD  CONSTRAINT [fkInventory_TagAlongs] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_TagAlongs] CHECK CONSTRAINT [fkInventory_TagAlongs]
GO
ALTER TABLE [dbo].[Inventory_Transfers_Serials_In]  WITH CHECK ADD  CONSTRAINT [fkInventory_Transfers_Serials_In] FOREIGN KEY([Store_ID], [Trans_ID])
REFERENCES [dbo].[Inventory_Transfers_In] ([Store_ID], [Trans_ID])
GO
ALTER TABLE [dbo].[Inventory_Transfers_Serials_In] CHECK CONSTRAINT [fkInventory_Transfers_Serials_In]
GO
ALTER TABLE [dbo].[Inventory_Transfers_Serials_Out]  WITH CHECK ADD  CONSTRAINT [fkInventory_Transfers_Serials_Out] FOREIGN KEY([Store_ID], [Trans_ID])
REFERENCES [dbo].[Inventory_Transfers_Out] ([Store_ID], [Trans_ID])
GO
ALTER TABLE [dbo].[Inventory_Transfers_Serials_Out] CHECK CONSTRAINT [fkInventory_Transfers_Serials_Out]
GO
ALTER TABLE [dbo].[Inventory_Vendors]  WITH CHECK ADD  CONSTRAINT [fkInventory_VendorsInventory] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Inventory_Vendors] CHECK CONSTRAINT [fkInventory_VendorsInventory]
GO
ALTER TABLE [dbo].[Invoice_Deliveries]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Deliveries] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_Deliveries] CHECK CONSTRAINT [fkInvoice_Deliveries]
GO
ALTER TABLE [dbo].[Invoice_Itemized]  WITH CHECK ADD  CONSTRAINT [fkInvoice_ItemizedInvoice_Totals] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_Itemized] CHECK CONSTRAINT [fkInvoice_ItemizedInvoice_Totals]
GO
ALTER TABLE [dbo].[Invoice_Itemized_ItemNotes]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Itemized_ItemNotes] FOREIGN KEY([Store_ID], [Invoice_Number], [LineNum])
REFERENCES [dbo].[Invoice_Itemized] ([Store_ID], [Invoice_Number], [LineNum])
GO
ALTER TABLE [dbo].[Invoice_Itemized_ItemNotes] CHECK CONSTRAINT [fkInvoice_Itemized_ItemNotes]
GO
ALTER TABLE [dbo].[Invoice_Itemized_Layaway]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Itemized_Layaway] FOREIGN KEY([Store_ID], [Invoice_Number], [LineNum])
REFERENCES [dbo].[Invoice_Itemized] ([Store_ID], [Invoice_Number], [LineNum])
GO
ALTER TABLE [dbo].[Invoice_Itemized_Layaway] CHECK CONSTRAINT [fkInvoice_Itemized_Layaway]
GO
ALTER TABLE [dbo].[Invoice_Itemized_Return_Details]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Itemized_Return_Details] FOREIGN KEY([Store_ID], [Invoice_Number], [LineNum])
REFERENCES [dbo].[Invoice_Itemized] ([Store_ID], [Invoice_Number], [LineNum])
GO
ALTER TABLE [dbo].[Invoice_Itemized_Return_Details] CHECK CONSTRAINT [fkInvoice_Itemized_Return_Details]
GO
ALTER TABLE [dbo].[Invoice_OnHold]  WITH CHECK ADD  CONSTRAINT [fkInvoice_OnHold] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_OnHold] CHECK CONSTRAINT [fkInvoice_OnHold]
GO
ALTER TABLE [dbo].[Invoice_Serial_Sales]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Serial_Sales] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_Serial_Sales] CHECK CONSTRAINT [fkInvoice_Serial_Sales]
GO
ALTER TABLE [dbo].[Invoice_Signatures]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Signatures] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_Signatures] CHECK CONSTRAINT [fkInvoice_Signatures]
GO
ALTER TABLE [dbo].[Invoice_SubCheck]  WITH CHECK ADD  CONSTRAINT [fkInvoice_SubCheck] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_SubCheck] CHECK CONSTRAINT [fkInvoice_SubCheck]
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Items]  WITH CHECK ADD  CONSTRAINT [fkInvoice_SubCheck_ItemsInvoice_SubCheck] FOREIGN KEY([Store_ID], [Invoice_Number], [SubCheckNum])
REFERENCES [dbo].[Invoice_SubCheck] ([Store_ID], [Invoice_Number], [SubCheckNum])
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Items] CHECK CONSTRAINT [fkInvoice_SubCheck_ItemsInvoice_SubCheck]
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Payments]  WITH CHECK ADD  CONSTRAINT [fkInvoice_SubCheck_Payments] FOREIGN KEY([Store_ID], [Invoice_Number], [SubCheckNum])
REFERENCES [dbo].[Invoice_SubCheck] ([Store_ID], [Invoice_Number], [SubCheckNum])
GO
ALTER TABLE [dbo].[Invoice_SubCheck_Payments] CHECK CONSTRAINT [fkInvoice_SubCheck_Payments]
GO
ALTER TABLE [dbo].[Invoice_SubModifiers]  WITH CHECK ADD  CONSTRAINT [fkInvoice_SubModifiers_To_Invoice_Itemized] FOREIGN KEY([Store_ID], [Invoice_Number], [LineNum])
REFERENCES [dbo].[Invoice_Itemized] ([Store_ID], [Invoice_Number], [LineNum])
GO
ALTER TABLE [dbo].[Invoice_SubModifiers] CHECK CONSTRAINT [fkInvoice_SubModifiers_To_Invoice_Itemized]
GO
ALTER TABLE [dbo].[Invoice_Totals_Notes]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Totals_Notes] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_Totals_Notes] CHECK CONSTRAINT [fkInvoice_Totals_Notes]
GO
ALTER TABLE [dbo].[Invoice_Totals_Person_Mapping]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Totals_Person_Mapping] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_Totals_Person_Mapping] CHECK CONSTRAINT [fkInvoice_Totals_Person_Mapping]
GO
ALTER TABLE [dbo].[Invoice_Totals_ShipTos]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Totals_ShipTos] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_Totals_ShipTos] CHECK CONSTRAINT [fkInvoice_Totals_ShipTos]
GO
ALTER TABLE [dbo].[Invoice_Totals_TaxExempt]  WITH CHECK ADD  CONSTRAINT [fkInvoice_Totals_TaxExempt] FOREIGN KEY([Store_ID], [Invoice_Number])
REFERENCES [dbo].[Invoice_Totals] ([Store_ID], [Invoice_Number])
GO
ALTER TABLE [dbo].[Invoice_Totals_TaxExempt] CHECK CONSTRAINT [fkInvoice_Totals_TaxExempt]
GO
ALTER TABLE [dbo].[Kit_Index]  WITH CHECK ADD  CONSTRAINT [fkKit_Index] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Kit_Index] CHECK CONSTRAINT [fkKit_Index]
GO
ALTER TABLE [dbo].[Loyalty_Items_Inclusions]  WITH CHECK ADD  CONSTRAINT [fkLoyalty_Items_Inclusions] FOREIGN KEY([Store_ID], [Loyalty_Item_ID])
REFERENCES [dbo].[Loyalty_Items] ([Store_ID], [Loyalty_Item_ID])
GO
ALTER TABLE [dbo].[Loyalty_Items_Inclusions] CHECK CONSTRAINT [fkLoyalty_Items_Inclusions]
GO
ALTER TABLE [dbo].[Loyalty_Plans_Items]  WITH CHECK ADD  CONSTRAINT [fkLoyalty_Plans_Items] FOREIGN KEY([Loyalty_Plan_ID])
REFERENCES [dbo].[Loyalty_Plans] ([Loyalty_Plan_ID])
GO
ALTER TABLE [dbo].[Loyalty_Plans_Items] CHECK CONSTRAINT [fkLoyalty_Plans_Items]
GO
ALTER TABLE [dbo].[metric_by_day]  WITH CHECK ADD  CONSTRAINT [FK_metric_by_day_date_id_dim_date_date_id] FOREIGN KEY([date_id])
REFERENCES [dbo].[dim_date] ([date_id])
GO
ALTER TABLE [dbo].[metric_by_day] CHECK CONSTRAINT [FK_metric_by_day_date_id_dim_date_date_id]
GO
ALTER TABLE [dbo].[metric_by_day]  WITH CHECK ADD  CONSTRAINT [FK_metric_by_day_metric_id_metric_metric_id] FOREIGN KEY([metric_id])
REFERENCES [dbo].[metric] ([id])
GO
ALTER TABLE [dbo].[metric_by_day] CHECK CONSTRAINT [FK_metric_by_day_metric_id_metric_metric_id]
GO
ALTER TABLE [dbo].[metric_by_time]  WITH CHECK ADD  CONSTRAINT [FK_metric_by_time_date_id_dim_date_date_id] FOREIGN KEY([date_id])
REFERENCES [dbo].[dim_date] ([date_id])
GO
ALTER TABLE [dbo].[metric_by_time] CHECK CONSTRAINT [FK_metric_by_time_date_id_dim_date_date_id]
GO
ALTER TABLE [dbo].[metric_by_time]  WITH CHECK ADD  CONSTRAINT [FK_metric_by_time_metric_id_metric_metric_id] FOREIGN KEY([metric_id])
REFERENCES [dbo].[metric] ([id])
GO
ALTER TABLE [dbo].[metric_by_time] CHECK CONSTRAINT [FK_metric_by_time_metric_id_metric_metric_id]
GO
ALTER TABLE [dbo].[metric_by_time]  WITH CHECK ADD  CONSTRAINT [FK_metric_by_time_time_id_dim_time_time_id] FOREIGN KEY([time_id])
REFERENCES [dbo].[dim_time] ([time_id])
GO
ALTER TABLE [dbo].[metric_by_time] CHECK CONSTRAINT [FK_metric_by_time_time_id_dim_time_time_id]
GO
ALTER TABLE [dbo].[Mobile_PO_Details]  WITH CHECK ADD  CONSTRAINT [fkMobile_PO_Details] FOREIGN KEY([PO_Number], [Store_Id], [DeviceID])
REFERENCES [dbo].[Mobile_PO_Summary] ([PO_Number], [Store_ID], [DeviceId])
GO
ALTER TABLE [dbo].[Mobile_PO_Details] CHECK CONSTRAINT [fkMobile_PO_Details]
GO
ALTER TABLE [dbo].[Modifiers]  WITH CHECK ADD  CONSTRAINT [fkModifiers] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Modifiers] CHECK CONSTRAINT [fkModifiers]
GO
ALTER TABLE [dbo].[Payment_Types]  WITH CHECK ADD  CONSTRAINT [fkPayment_Types] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Payment_Types] CHECK CONSTRAINT [fkPayment_Types]
GO
ALTER TABLE [dbo].[Pizza_Modifier_SubModifiers]  WITH CHECK ADD  CONSTRAINT [fkPizza_Modifier_SubModifiers_SubModifiers] FOREIGN KEY([Store_ID], [SubModifierNumber])
REFERENCES [dbo].[SubModifiers] ([Store_ID], [ID])
GO
ALTER TABLE [dbo].[Pizza_Modifier_SubModifiers] CHECK CONSTRAINT [fkPizza_Modifier_SubModifiers_SubModifiers]
GO
ALTER TABLE [dbo].[Pizza_Modifiers]  WITH CHECK ADD  CONSTRAINT [fkPizza_Modifiers_Modifier_Inventory] FOREIGN KEY([Store_ID], [ModifierItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Pizza_Modifiers] CHECK CONSTRAINT [fkPizza_Modifiers_Modifier_Inventory]
GO
ALTER TABLE [dbo].[Pizza_Modifiers]  WITH CHECK ADD  CONSTRAINT [fkPizza_Modifiers_Pizza_Inventory] FOREIGN KEY([Store_ID], [PizzaItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Pizza_Modifiers] CHECK CONSTRAINT [fkPizza_Modifiers_Pizza_Inventory]
GO
ALTER TABLE [dbo].[Pizza_Modifiers]  WITH CHECK ADD  CONSTRAINT [fkPizza_Modifiers_Pizza_Regions] FOREIGN KEY([Store_ID], [PizzaRegion])
REFERENCES [dbo].[Pizza_Regions] ([Store_ID], [ID])
GO
ALTER TABLE [dbo].[Pizza_Modifiers] CHECK CONSTRAINT [fkPizza_Modifiers_Pizza_Regions]
GO
ALTER TABLE [dbo].[Pizza_Prices]  WITH CHECK ADD  CONSTRAINT [fkPizza_Prices_Crust_Inventory] FOREIGN KEY([Store_ID], [CrustItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Pizza_Prices] CHECK CONSTRAINT [fkPizza_Prices_Crust_Inventory]
GO
ALTER TABLE [dbo].[Pizza_Prices]  WITH CHECK ADD  CONSTRAINT [fkPizza_Prices_Pizza_Inventory] FOREIGN KEY([Store_ID], [PizzaItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Pizza_Prices] CHECK CONSTRAINT [fkPizza_Prices_Pizza_Inventory]
GO
ALTER TABLE [dbo].[Pizza_Prices]  WITH CHECK ADD  CONSTRAINT [fkPizza_Prices_Size_Inventory] FOREIGN KEY([Store_ID], [SizeItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Pizza_Prices] CHECK CONSTRAINT [fkPizza_Prices_Size_Inventory]
GO
ALTER TABLE [dbo].[Pizza_Topping_Prices]  WITH CHECK ADD  CONSTRAINT [fkPizza_Topping_Prices_Size_Inventory] FOREIGN KEY([Store_ID], [SizeItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Pizza_Topping_Prices] CHECK CONSTRAINT [fkPizza_Topping_Prices_Size_Inventory]
GO
ALTER TABLE [dbo].[Pizza_Topping_Prices]  WITH CHECK ADD  CONSTRAINT [fkPizza_Topping_Prices_Topping_Inventory] FOREIGN KEY([Store_ID], [ToppingItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Pizza_Topping_Prices] CHECK CONSTRAINT [fkPizza_Topping_Prices_Topping_Inventory]
GO
ALTER TABLE [dbo].[PO_Authorizations]  WITH CHECK ADD  CONSTRAINT [fkPO_Authorizations] FOREIGN KEY([Store_ID], [PO_Number])
REFERENCES [dbo].[PO_Summary] ([Store_ID], [PO_Number])
GO
ALTER TABLE [dbo].[PO_Authorizations] CHECK CONSTRAINT [fkPO_Authorizations]
GO
ALTER TABLE [dbo].[PO_Charges]  WITH CHECK ADD  CONSTRAINT [fkPO_Charges] FOREIGN KEY([Store_ID], [PO_Number])
REFERENCES [dbo].[PO_Summary] ([Store_ID], [PO_Number])
GO
ALTER TABLE [dbo].[PO_Charges] CHECK CONSTRAINT [fkPO_Charges]
GO
ALTER TABLE [dbo].[PO_Details]  WITH CHECK ADD  CONSTRAINT [fkPO_Details] FOREIGN KEY([Store_ID], [PO_Number])
REFERENCES [dbo].[PO_Summary] ([Store_ID], [PO_Number])
GO
ALTER TABLE [dbo].[PO_Details] CHECK CONSTRAINT [fkPO_Details]
GO
ALTER TABLE [dbo].[PO_Details_CostDisc]  WITH CHECK ADD  CONSTRAINT [fkPO_Details_CostDisc] FOREIGN KEY([Store_ID], [PO_Number], [LineNum])
REFERENCES [dbo].[PO_Details] ([Store_ID], [PO_Number], [LineNum])
GO
ALTER TABLE [dbo].[PO_Details_CostDisc] CHECK CONSTRAINT [fkPO_Details_CostDisc]
GO
ALTER TABLE [dbo].[PO_Details_StoreListing]  WITH CHECK ADD  CONSTRAINT [fkPO_Details_StoreListing] FOREIGN KEY([Store_ID], [PO_Number], [LineNum])
REFERENCES [dbo].[PO_Details] ([Store_ID], [PO_Number], [LineNum])
GO
ALTER TABLE [dbo].[PO_Details_StoreListing] CHECK CONSTRAINT [fkPO_Details_StoreListing]
GO
ALTER TABLE [dbo].[PO_Payments]  WITH CHECK ADD  CONSTRAINT [fkPO_Payments] FOREIGN KEY([Store_ID], [PO_Number])
REFERENCES [dbo].[PO_Summary] ([Store_ID], [PO_Number])
GO
ALTER TABLE [dbo].[PO_Payments] CHECK CONSTRAINT [fkPO_Payments]
GO
ALTER TABLE [dbo].[Printer_Mapping]  WITH CHECK ADD  CONSTRAINT [fkPrinter_Mapping] FOREIGN KEY([Store_ID], [Station_ID])
REFERENCES [dbo].[Stations] ([Store_ID], [Station_ID])
GO
ALTER TABLE [dbo].[Printer_Mapping] CHECK CONSTRAINT [fkPrinter_Mapping]
GO
ALTER TABLE [dbo].[Printers]  WITH CHECK ADD  CONSTRAINT [fkPrinters] FOREIGN KEY([Store_ID], [ItemNum])
REFERENCES [dbo].[Inventory] ([Store_ID], [ItemNum])
GO
ALTER TABLE [dbo].[Printers] CHECK CONSTRAINT [fkPrinters]
GO
ALTER TABLE [dbo].[Properties]  WITH CHECK ADD  CONSTRAINT [fkProperties] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Properties] CHECK CONSTRAINT [fkProperties]
GO
ALTER TABLE [dbo].[Reports_Custom]  WITH CHECK ADD  CONSTRAINT [fkReports_Custom] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Reports_Custom] CHECK CONSTRAINT [fkReports_Custom]
GO
ALTER TABLE [dbo].[Reports_Setup]  WITH CHECK ADD  CONSTRAINT [fkReports_Setup] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Reports_Setup] CHECK CONSTRAINT [fkReports_Setup]
GO
ALTER TABLE [dbo].[Setup_DiscLevels]  WITH CHECK ADD  CONSTRAINT [fkSetup_DiscLevels] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Setup_DiscLevels] CHECK CONSTRAINT [fkSetup_DiscLevels]
GO
ALTER TABLE [dbo].[Setup_Reason_Codes]  WITH CHECK ADD  CONSTRAINT [fkSetup_Reason_Codes] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Setup_Reason_Codes] CHECK CONSTRAINT [fkSetup_Reason_Codes]
GO
ALTER TABLE [dbo].[Setup_TS_Buttons_Schedule_DaysTimes]  WITH CHECK ADD  CONSTRAINT [fkSetup_TS_Buttons_Schedule_DaysTimes] FOREIGN KEY([Store_ID], [ScheduleIndex])
REFERENCES [dbo].[Setup_TS_Buttons_Schedule] ([Store_ID], [ScheduleIndex])
GO
ALTER TABLE [dbo].[Setup_TS_Buttons_Schedule_DaysTimes] CHECK CONSTRAINT [fkSetup_TS_Buttons_Schedule_DaysTimes]
GO
ALTER TABLE [dbo].[ShiftsMediaTypes]  WITH CHECK ADD  CONSTRAINT [ShiftsMediaTypesShifts] FOREIGN KEY([RowID])
REFERENCES [dbo].[Shifts] ([RowID])
GO
ALTER TABLE [dbo].[ShiftsMediaTypes] CHECK CONSTRAINT [ShiftsMediaTypesShifts]
GO
ALTER TABLE [dbo].[ShiftsMediaTypesCount]  WITH CHECK ADD  CONSTRAINT [ShiftsMediaTypesCountShiftMediaTypes] FOREIGN KEY([RowID], [MediaType])
REFERENCES [dbo].[ShiftsMediaTypes] ([RowID], [MediaType])
GO
ALTER TABLE [dbo].[ShiftsMediaTypesCount] CHECK CONSTRAINT [ShiftsMediaTypesCountShiftMediaTypes]
GO
ALTER TABLE [dbo].[ShiftsMediaTypesSubTypes]  WITH CHECK ADD  CONSTRAINT [ShiftsMediaTypesSubTypesCountShiftMediaTypes] FOREIGN KEY([RowID], [MediaType])
REFERENCES [dbo].[ShiftsMediaTypes] ([RowID], [MediaType])
GO
ALTER TABLE [dbo].[ShiftsMediaTypesSubTypes] CHECK CONSTRAINT [ShiftsMediaTypesSubTypesCountShiftMediaTypes]
GO
ALTER TABLE [dbo].[Stations]  WITH CHECK ADD  CONSTRAINT [fkStations] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Stations] CHECK CONSTRAINT [fkStations]
GO
ALTER TABLE [dbo].[Stations_CD]  WITH CHECK ADD  CONSTRAINT [fkStations_CD] FOREIGN KEY([Store_ID], [Station_ID])
REFERENCES [dbo].[Stations] ([Store_ID], [Station_ID])
GO
ALTER TABLE [dbo].[Stations_CD] CHECK CONSTRAINT [fkStations_CD]
GO
ALTER TABLE [dbo].[Store_Group_Details]  WITH CHECK ADD  CONSTRAINT [Store_Group_DetailsStore_Group] FOREIGN KEY([Store_Group_ID])
REFERENCES [dbo].[Store_Group] ([Store_Group_ID])
GO
ALTER TABLE [dbo].[Store_Group_Details] CHECK CONSTRAINT [Store_Group_DetailsStore_Group]
GO
ALTER TABLE [dbo].[Table_Diagram]  WITH CHECK ADD  CONSTRAINT [fkTable_Diagram] FOREIGN KEY([Store_ID], [Section_ID])
REFERENCES [dbo].[Table_Diagram_Sections] ([Store_ID], [Section_ID])
GO
ALTER TABLE [dbo].[Table_Diagram] CHECK CONSTRAINT [fkTable_Diagram]
GO
ALTER TABLE [dbo].[Table_Diagram_Sections]  WITH CHECK ADD  CONSTRAINT [fkTable_Diagram_Sections] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Table_Diagram_Sections] CHECK CONSTRAINT [fkTable_Diagram_Sections]
GO
ALTER TABLE [dbo].[Tax_Rate]  WITH CHECK ADD  CONSTRAINT [fkTax_Rate] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Tax_Rate] CHECK CONSTRAINT [fkTax_Rate]
GO
ALTER TABLE [dbo].[Tax_Table]  WITH CHECK ADD  CONSTRAINT [fkTax_Table] FOREIGN KEY([Store_ID])
REFERENCES [dbo].[Setup] ([Store_ID])
GO
ALTER TABLE [dbo].[Tax_Table] CHECK CONSTRAINT [fkTax_Table]
GO
ALTER TABLE [dbo].[Time_Clock_Breaks]  WITH CHECK ADD  CONSTRAINT [fkTime_Clock_BreaksTime_Clock] FOREIGN KEY([Store_ID], [ID])
REFERENCES [dbo].[Time_Clock] ([Store_ID], [ID])
GO
ALTER TABLE [dbo].[Time_Clock_Breaks] CHECK CONSTRAINT [fkTime_Clock_BreaksTime_Clock]
GO
ALTER TABLE [dbo].[Time_Clock_Cash_Count]  WITH CHECK ADD  CONSTRAINT [fkTime_Clock_Cash_CountTime_Clock] FOREIGN KEY([Store_ID], [ID])
REFERENCES [dbo].[Time_Clock] ([Store_ID], [ID])
GO
ALTER TABLE [dbo].[Time_Clock_Cash_Count] CHECK CONSTRAINT [fkTime_Clock_Cash_CountTime_Clock]
GO
ALTER TABLE [dbo].[Vendor_Store_Priorities]  WITH CHECK ADD  CONSTRAINT [fkVendor_Store_PrioritiesVendors] FOREIGN KEY([Vendor_Number])
REFERENCES [dbo].[Vendors] ([Vendor_Number])
GO
ALTER TABLE [dbo].[Vendor_Store_Priorities] CHECK CONSTRAINT [fkVendor_Store_PrioritiesVendors]
GO
ALTER TABLE [dbo].[Vendor_Stores]  WITH CHECK ADD  CONSTRAINT [fkVendor_Stores_Vendors] FOREIGN KEY([Vendor_Number])
REFERENCES [dbo].[Vendors] ([Vendor_Number])
GO
ALTER TABLE [dbo].[Vendor_Stores] CHECK CONSTRAINT [fkVendor_Stores_Vendors]
GO
ALTER TABLE [dbo].[Vendor_Templates]  WITH CHECK ADD  CONSTRAINT [fkVendor_Templates] FOREIGN KEY([Vendor_Number])
REFERENCES [dbo].[Vendors] ([Vendor_Number])
GO
ALTER TABLE [dbo].[Vendor_Templates] CHECK CONSTRAINT [fkVendor_Templates]
GO
ALTER TABLE [dbo].[Vendor_Templates_Items]  WITH CHECK ADD  CONSTRAINT [fkVendor_Templates_Items] FOREIGN KEY([Template_ID])
REFERENCES [dbo].[Vendor_Templates] ([Template_ID])
GO
ALTER TABLE [dbo].[Vendor_Templates_Items] CHECK CONSTRAINT [fkVendor_Templates_Items]
GO
ALTER TABLE [dbo].[Vendor_Terms]  WITH CHECK ADD  CONSTRAINT [fkVendor_Terms] FOREIGN KEY([Vendor_Number])
REFERENCES [dbo].[Vendors] ([Vendor_Number])
GO
ALTER TABLE [dbo].[Vendor_Terms] CHECK CONSTRAINT [fkVendor_Terms]
GO
/****** Object:  StoredProcedure [dbo].[calculate_labor_edits]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[calculate_labor_edits]
	@timeClockId bigint,
	@storeId varchar(10),
	@startDateTime varchar(25),
	@endDateTime varchar(25)
AS
	Set nocount on

	--overtime calculation
	declare @SixtyInDecimal decimal(12,2)
	declare @workweekStartDay int
	declare @overtimeCalculationMethod int
	declare @endDateTimeToUseForCalc datetime 

	select @SixtyInDecimal = convert(decimal(12,2),60)
	select @endDateTimeToUseForCalc = convert(DateTime,@endDateTime)

	-- 0 sunday, 1 monday, etc, from CRE, SQL starts at 1
	select @workweekStartDay = (select workweekstartday from setup where store_Id = @storeId)

	-- make the adjustment here, as were working in SQL (SQL starts at 1)
	select @workweekStartDay = @workweekStartDay + 1

	-- 0 is weekly, 1 is daily
	select @overtimeCalculationMethod = (select IsNull(OvertimeCalculationMethod,0) from setup where store_Id = @storeId)

	-- calculate start time
	Set @startDateTime =  isnull((select min(StartDateTime) 
		from Time_Clock  
		where (EndDateTime is  null or EndDateTime = '' or EndDateTime between  @startDateTime and  @endDateTime )),@startDateTime)

	select 	case when endDateTime IS NULL THEN '1' ELSE '0' END as IsStillLoggedIn,
		convert(bit,0) as isOutOfRange, -- requires out of range records to calculate overtime, were not going to output these
		convert(int,0) as periodNo,
		convert(int,0) as OrigTotalMinutes,
		Convert(int,0) as NumMinutesBreak,
		convert(Decimal(12,2),isnull(NumMinutes,0)) as NumMinutes,
		convert(Decimal(12,2),isnull(NumMinutes,0) ) as TotalMinutes,		
		convert(Decimal(12,2), isnull((round(wages/NULLIF(hourly_wage, 0),0) * 60),0) ) as RegularMinutes,
		convert(Decimal(12,2), 0) as OvertimeMinutes,
		convert(Decimal(12,2), 0) as OvertimeMinutesAtTimeAndAHalf,
		convert(Decimal(12,2), 0) as OvertimeMinutesAtDoubleTime,
		convert(Decimal(12,2), 0) as TotalHours,
		convert(Decimal(12,2), 0) as RegularHours,
		CONVERT(DECIMAL(12,2), 0) as overtimeHours,
		convert(Decimal(12,2), 0) as wages, 		
		convert(Decimal(12,2), 0) as OvertimeWagesAtTimeAndAHalf,		
		convert(Decimal(12,2), 0) as OvertimeWagesAtDoubleTime,				
		convert(Decimal(12,2),hourly_wage) as 'hourly_wage' , 
		convert(Decimal(12,2), taxes) as 'taxes', 
		convert(Decimal(12,2), tips) as 'tips',
		convert(Decimal(12,2), OverTimeHourly_Wage) as 'OverTimeHourly_Wage',		
		convert(Decimal(12,2), 0) as  OvertimeWagesEarned,
		convert(int,0) as DaysInARow,
		convert(Decimal(12,2), 0) as NumMinutesBreakPaid, 
		convert(Decimal(12,2), 0) as NumMinutesBreakUnpaid, 
		[status],
		store_id, 
		cashier_id, 
		Id, 
		JobCodeId, 
		startDateTime, 
		case when endDateTime IS NULL THEN @endDateTimeToUseForCalc ELSE endDateTime END as endDateTime,
		convert(Decimal(12,2), 0) as Total_Cash_Sales, 
		convert(varchar(20),'') as payroll_employee_number,
		convert(varchar(60),'') as payname,
		convert(varchar(10),'') as startDate,
		convert(varchar(10),'') as startTime,
		convert(varchar(10),'') as endTime,
		convert(varchar(10),'') as dateIn,
		convert(varchar(10),'') as dateOut,
		convert(decimal(12,2),0) as doubleTimeRate,
		convert(varchar(10),'') as overtimeStarts,
		convert(varchar(20),'') as jobcode_desc,
		convert(varchar(20),'') as transactionId,
		convert(Decimal(12,2), 0) as charge_tips,
		convert(Decimal(12,2), 0) as Cash_Tips_Taken,
		ClockOutStation_ID
		into #timeclockRaw
        from time_clock
        where  
			ID = @timeClockId
			order by cashier_Id, startDateTime, jobcodeId

		declare @startDateForPayPeriod DateTime ;	
		declare @dtTemp datetime
		select @dtTemp = (select min(startDateTime) from #timeclockRaw)								
		select @startDateForPayPeriod = [dbo].getStartDateOfPayPeriod(@dtTemp, @workweekStartDay) -- -> is the startDate of payperiod = 0


		insert into #timeclockRaw (id, store_id, cashier_id, isOutOfRange, IsStillLoggedIn, StartDateTime, EndDateTime,[status],
		JobCodeID, ClockOutStation_ID, hourly_wage, OverTimeHourly_Wage, NumMinutesBreak,
		OvertimeMinutesAtTimeAndAHalf, OvertimeMinutesAtDoubleTime,
		DaysInARow, NumMinutesBreakPaid, NumMinutesBreakUnpaid,
		Total_Cash_Sales, Cash_Tips_Taken
		)		
	select 
		id,
		store_id,
		cashier_id,
		1 as isOutOfRange, 
		case when endDateTime IS NULL THEN '1' ELSE '0' END as IsStillLoggedIn,
		StartDateTime,
		case when endDateTime IS NULL THEN @endDateTimeToUseForCalc ELSE endDateTime END as endDateTime,
		[status],
		JobCodeID,
		ClockOutStation_ID,
		Hourly_Wage,
		OvertimeHourly_Wage,
		0 as NumMinutesBreak,
		0 as OvertimeMinutesAtTimeAndAHalf,
		0 as OvertimeMinutesAtDoubleTime,
		0 as DaysInARow,
		0 as NumMinutesBreakPaid,
		0 as NumMinutesBreakUnpaid,
		0 as Total_Cash_Sales,
		0 as Cash_Tips_Taken
	from Time_Clock
	where
	ID = @timeClockId


		--This is where #timeclock temp table is created
		select * into #timeclock
		from #timeclockRaw
		order by cashier_Id, startDateTime, jobcodeId
				
	update #timeclock set payname = 
			isnull(emp.first_Name + ' ' +  emp.Last_Name,'undefined, ' + tc.Cashier_ID)
			from employee emp, #timeclock tc
			where emp.cashier_id = tc.cashier_id


	--- get the employee payroll number (even if we may not need it yet)
	update #timeclock set payroll_employee_number = emp.payroll_employee_number
			from Employee_AdditionalInfo emp, #timeclock tc
			where emp.cashier_id = tc.cashier_id
			
			--- set up the temporary #timeclockbreaks
		--- it's a one to many from the #timeclock to the timeclock breaks
		select 
			case when b.BreakEndDateTime IS NULL THEN '1' ELSE '0' END as IsBreakOpen,
			convert(varchar(10),'') as dateIn,
			convert(varchar(10),'') as startTime,
			convert(varchar(10),'') as endTime,
			convert(varchar(10),'') as dateOut,
			convert(varchar(20),'') as cashierId,
			convert(varchar(20),'') as payname,
			convert(varchar(20),'') as JobCodeId,
			convert(varchar(20),'') as jobcode_desc,
			convert(varchar(20),'') as transactionId,
			convert(varchar(20),'') as clockoutstation_id,
			case when b.paid = 1 THEN 'true' ELSE 'false' END as isPaidBreak,
			case when b.paid = 0 THEN 'true' ELSE 'false' END as isUnPaidBreak,
			b.* into #timeclockbreaks
			from Time_Clock_Breaks b, #timeclock t
			where b.ID = t.ID

		update #timeclockbreaks
			set BreakEndDateTime =  @endDateTimeToUseForCalc
			where BreakEndDateTime is null

		update #timeclockbreaks					
			set NumMinutesBreak = DATEDIFF(mi, BreakStartDateTime, BreakEndDateTime)			
			where IsBreakOpen = 1 and Paid = 0

		update #timeclockbreaks					
			set dateIn = FORMAT( BreakStartDateTime, 'MM/dd/yyyy', 'en-US' ),
				dateOut = FORMAT( BreakEndDateTime, 'MM/dd/yyyy', 'en-US' ),
				startTime = FORMAT( BreakStartDateTime, 'HH:mm', 'en-US' ),
				endTime = FORMAT( BreakEndDateTime, 'HH:mm', 'en-US' )


		--- if the break is open, then we have to ADD the NumMinutesBreak for OPEN breaks
		--- it's assumed that there is ONLY 1 open break
		update #timeclock					
			set NumMinutesBreak = t.NumMinutesBreak + DATEDIFF(mi, BreakStartDateTime, BreakEndDateTime)
			from #timeclock t, #timeclockbreaks b
			where t.id = b.Id
				and b.Paid = 0
				and b.IsBreakOpen = 1

		-- updates for logged in employees -----------------------------		
		
		--- calculate the minutes, using the incoming enddate time (now)
		update #timeclock
			set TotalMinutes = DATEDIFF(mi, StartDateTime, endDateTime),
				NumMinutes = DATEDIFF(mi, StartDateTime, endDateTime)
			where IsStillLoggedIn = 1


		--- get the jobcode name 
		update #timeclock
			set jobcode_desc = JobCode.JobCodeName
			from #timeclock, JobCode
			where #timeclock.JobCodeID = jobCode.JobCodeID
			

		--- update for breaks, note it's a sum on the timeclockbreaks as there may be one than one break				
		update #timeclock
			set NumMinutesBreak = tb.numMinutesBreak 
			from #timeClock tc, (select id, sum(NumMinutesBreak) as numMinutesBreak 
								from #timeclockbreaks
								where Paid = 0
								group by id
								) tb
			where tc.id = tb.ID

		update #timeclock
			set OrigTotalMinutes = DATEDIFF(mi, StartDateTime, EndDateTime)

		update #timeclock
			set TotalMinutes = iif(OrigTotalMinutes - NumMinutesBreak > 0,OrigTotalMinutes - NumMinutesBreak,0),
				NumMinutes = iif(OrigTotalMinutes - NumMinutesBreak > 0,OrigTotalMinutes - NumMinutesBreak,0)
	
		-- update for everybody, now that we have num minutes
		update #timeclock
			set TotalHours = Convert(Decimal(8,2), TotalMinutes/convert(decimal(5,2),60))
			
			
		-- specific record vars
		declare @cCashierId varchar(20)
		declare @cIsStillLoggedIn int
		Declare @cTotalMinutes Decimal(8,2)
		Declare @cPeriodNo int
		Declare @cId int
		declare @cStartDateTime DateTime

		declare @minutesForPeriod Decimal(8,2)
		-- 
		declare @fortyHoursInMinutes Decimal(8,2)
		select @fortyHoursInMinutes = 2400 ;

		declare @lastPeriodBreak varchar(30)
		select @lastPeriodBreak = '~'

		declare @lastSequentialDaysBreak varchar(30)
		select @lastSequentialDaysBreak = '~'
		declare @currentDaysBreak varchar(30)

		-- weekly method of overtime calculation -----------------------------
		if @overtimeCalculationMethod = 0 begin 
			
			update #timeclock set periodNo = convert(int,DateDiff(d, @startDateForPayPeriod, startDateTime) / 7)

			DECLARE db_cursor CURSOR FOR  
			SELECT cashier_id, IsStillLoggedIn, TotalMinutes, PeriodNo, Id
				FROM #timeclock 			
				order by cashier_id, periodNo, StartDateTime

			OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId
		
			WHILE @@FETCH_STATUS = 0   
			BEGIN   					
					declare @regTimeBucket Decimal(8,2)
					declare @otTimeBucket Decimal(8,2)
					declare @amtToAllocate2 Decimal(8,2)
					declare @minutesNeededToGetTo40 Decimal(8,2)

					select @amtToAllocate2 = @cTotalMinutes
					select @regTimeBucket = 0
					select @otTimeBucket = 0
					
					if( @lastPeriodBreak <> @cCashierId + convert(varchar(10),@cPeriodNo)) begin
						select @lastPeriodBreak = @cCashierId + convert(varchar(10),@cPeriodNo)					
						select @minutesForPeriod = 0
					end					
				
					--- if it all falls into overtime, before we add the accumulator
					if (@minutesForPeriod >= @fortyHoursInMinutes) begin
						-- were over the forty hour mark, prior to this entry, so it's all overtime
						select @otTimeBucket = @cTotalMinutes						
					end else begin
						-- how many minutes to we need to get it to 40
						select @minutesNeededToGetTo40 = iif(@fortyHoursInMinutes - @minutesForPeriod > 0,@fortyHoursInMinutes - @minutesForPeriod,0 )
						if @minutesNeededToGetTo40 > @amtToAllocate2 begin
							select @regTimeBucket = @amtToAllocate2
						end else begin
							select @regTimeBucket = iif(@cTotalMinutes - @minutesNeededToGetTo40 > 0,@minutesNeededToGetTo40, @cTotalMinutes)
							select @otTimeBucket = @cTotalMinutes - @regTimeBucket
						end 
					end
			
					update #timeclock set RegularMinutes = @regTimeBucket, OvertimeMinutes = @otTimeBucket
						where id = @cId
			
					select @minutesForPeriod = @minutesForPeriod + @cTotalMinutes				
			
					FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId			
			END   

			CLOSE db_cursor   
			DEALLOCATE db_cursor
						
			update #timeclock set wages = (RegularMinutes / 60) * Hourly_Wage,
					OvertimeWagesEarned = (OvertimeMinutes / 60) * OverTimeHourly_Wage,
					overtimeHours = OvertimeMinutes/@SixtyInDecimal					
		end 
		-- end of weekly overtime calculation
		
		-- daily method of overtime calculation -----------------------------
		if @overtimeCalculationMethod = 1 begin 			
			update #timeclock set periodNo = DATEPART(DAYOFYEAR, StartDateTime)
			
			-- under 8 hours is standard rate
			-- 8 - 12 is 1.5 standard rate
			declare @8HourThresholdInMinutes Decimal(8,2)
			select @8HourThresholdInMinutes = 480

			-- 12 and over is double time
			declare @12HourThresholdInMinutes Decimal(8,2)
			select @12HourThresholdInMinutes = 720

			declare @otTimeAndAHalf Decimal(8,2)
			declare @otDoubleTime Decimal(8,2)

			declare @workedDaysInARow int
			declare @workedDaysInARowDate DateTime 

			DECLARE db_cursor CURSOR FOR  
			SELECT cashier_id, IsStillLoggedIn, TotalMinutes, PeriodNo, Id, StartDateTime
				FROM #timeclock 			
				order by cashier_id, periodNo, StartDateTime

			OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId, @cStartDateTime
		
			WHILE @@FETCH_STATUS = 0   
			BEGIN   
					--- update for current record
					select @otTimeAndAHalf = 0
					select @otDoubleTime = 0
					select @regTimeBucket = 0
					
					--- temp vars
					declare @minutesNeededToGetTo8 Decimal(8,2)
					declare @minutesNeededToGetTo12 Decimal(8,2)

					--- this is for a period break (per day, in daily)
					if( @lastPeriodBreak <> @cCashierId + convert(varchar(10),@cPeriodNo)) begin
						select @lastPeriodBreak = @cCashierId + convert(varchar(10),@cPeriodNo)					
						select @minutesForPeriod = 0						
					end
					
					--- set up for 7th day worked in a row
					declare @payPeriod int
					declare @breakDateFor7thDate datetime 
					declare @currentDateFor7thDate datetime 
					select @payPeriod = convert(int,DateDiff(d, @startDateForPayPeriod, @cStartDateTime) / 7)					

					select @currentDaysBreak = @ccashierId + '.' + Convert(varchar(4), @payPeriod)					
					if @lastSequentialDaysBreak <> @currentDaysBreak begin					
						select @lastSequentialDaysBreak = @currentDaysBreak						
						select @workedDaysInARow = 0
						select @breakDateFor7thDate = [dbo].getStartDateOfPayPeriod(@cStartDateTime,@workweekStartDay)	
					end
					
					if DatePart(dy,@cStartDateTime) = DatePart(dy,@breakDateFor7thDate) begin
						select @workedDaysInARow = @workedDaysInARow + 1
						select @breakDateFor7thDate = DateAdd(dd,1, @breakDateFor7thDate)
					end 

					declare @diff Decimal(8,2)
					declare @amtToAllocate Decimal(8,2)					
					select @amtToAllocate = @cTotalMinutes
					
					select @minutesNeededToGetTo8 = @8HourThresholdInMinutes - @minutesForPeriod
					
					if @workedDaysInARow = 7 begin
						select @otTimeAndAHalf = iif(@amtToAllocate <= @minutesNeededToGetTo8, @amtToAllocate, @minutesNeededToGetTo8)
						select @amtToAllocate = @amtToAllocate - @otTimeAndAHalf
						select @otDoubleTime = iif(@amtToAllocate > 0, @amtToAllocate, 0)
					end else begin
						if @minutesNeededToGetTo8 > 0 begin						
							select @regTimeBucket = iif(@minutesNeededToGetTo8 - @amtToAllocate > 0,@amtToAllocate, @minutesNeededToGetTo8)
							
							select @amtToAllocate = @amtToAllocate - @regTimeBucket   
							--select @cId, @regTimeBucket, @amtToAllocate
							--- add to summary total
							select @minutesForPeriod = @minutesForPeriod + @regTimeBucket				
						end 
					 
						--- were in the 8-12 range
						select @minutesNeededToGetTo12 = @12HourThresholdInMinutes - @minutesForPeriod
						if @minutesNeededToGetTo12 > 0 begin						
							select @otTimeAndAHalf = iif(@minutesNeededToGetTo12 - @amtToAllocate > 0, @amtToAllocate, @minutesNeededToGetTo12)
							select @amtToAllocate = @amtToAllocate - @otTimeAndAHalf   
						
							--- add to summary total
							select @minutesForPeriod = @minutesForPeriod + @otTimeAndAHalf				
						end 

						if @amtToAllocate > 0 begin
							select @otDoubleTime = @amtToAllocate
							select @minutesForPeriod = @minutesForPeriod + @otDoubleTime
							select @amtToAllocate = 0
						end
					end
					update #timeclock set RegularMinutes = @regTimeBucket,
							OvertimeMinutesAtTimeAndAHalf = @otTimeAndAHalf,
							OvertimeMinutesAtDoubleTime = @otDoubleTime,
							DaysInARow = @workedDaysInARow
							where Id = @cId

					FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId, @cStartDateTime
			END   

			CLOSE db_cursor   
			DEALLOCATE db_cursor

			update #timeclock set OvertimeWagesEarned = OvertimeWagesAtTimeAndAHalf + OvertimeWagesAtDoubleTime,
					OvertimeMinutes = OvertimeMinutesAtTimeAndAHalf + OvertimeMinutesAtDoubleTime,
					overtimeHours = (OvertimeMinutesAtDoubleTime + OvertimeMinutesAtTimeAndAHalf)/@SixtyInDecimal
		end

	SELECT
	FORMAT(tc.StartDateTime, 'MM/dd/yyyy', 'en-US') as startDate,
	FORMAT(tc.StartDateTime, 'HH:mm', 'en-US') as startTime,
	FORMAT(tc.EndDateTime, 'HH:mm', 'en-US') as endTime,
	Convert(int,tc.id) + 5000000 as transactionId,
	tc.Cashier_ID as cashierId,
	isnull(emp.first_Name + ' ' +  emp.Last_Name,'undefined, ' + tc.Cashier_ID) as payname,
	tc.JobCodeID as jobCodeId,
	jc.JobCodeName as jobcode_desc,
	tc.ClockOutStation_ID as clockoutstation_id,
	FORMAT( tc.StartDateTime ,'MM/dd/yyyy', 'en-US') as dateIn,
	FORMAT( tc.EndDateTime ,'MM/dd/yyyy','en-US') as dateOut,
	tc.Wages as wages,
	tc.Hourly_Wage as hourly_wage,
	tc.OvertimeWagesEarned as OvertimeWagesEarned,
	CASE WHEN @overtimeCalculationMethod = 0 THEN convert(Decimal(12,2), OverTimeHourly_Wage) ELSE convert(Decimal(12,2), tc.Hourly_Wage * 1.5) END as 'OverTimeHourly_Wage',
	tc.Hourly_Wage * 2 as doubleTimeRate,
	tc.Total_Cash_Sales as Total_Cash_Sales,
	empa.payroll_employee_number as payroll_employee_number,
	
	(tc.Wages/NULLIF(tc.Hourly_Wage,0))*60 as RegularMinutes,
	((tc.Wages/NULLIF(tc.Hourly_Wage,0))*60) /60 as regularHours,
	
	ISNULL((select overtimeHours from #timeclock where isOutOfRange = 1), 0.00) as overtimeHours,
	ISNULL((select OvertimeMinutes from #timeclock where isOutOfRange = 1), 0.00) as overtimeMinutes,
	tc.Tips as cash_tips
	from Time_Clock tc 
	inner join employee emp on tc.Cashier_ID = emp.Cashier_ID
	inner join JobCode jc on tc.JobCodeID = jc.JobCodeID
	inner join Employee_AdditionalInfo empa on tc.Cashier_ID = empa.Cashier_ID
	where tc.ID = @timeClockId
GO
/****** Object:  StoredProcedure [dbo].[COGS_RptDS]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

        -- =============================================
        -- Author:		<Irek Janek>
        -- Create date: <9/11/2020>
        -- Description:	<COGS Report Data Source>
        -- =============================================
        CREATE PROCEDURE [dbo].[COGS_RptDS]
	        @sDate1 DATE, 
	        @eDate1 DATE, 
	        @sDate2 DATE, 
	        @eDate2 DATE
        AS
        DECLARE @currentDate DATE,
		        @currentStock DECIMAL(18,2),
		        @receivedSince1Start DECIMAL(18,2),
		        @receivedSince1End DECIMAL(18,2),
		        @receivedSince2Start DECIMAL(18,2),
		        @receivedSince2End DECIMAL(18,2),
		        @stockMoveSince1Start DECIMAL(18,2),
		        @stockMoveSince1End DECIMAL(18,2),
		        @stockMoveSince2Start DECIMAL(18,2),
		        @stockMoveSince2End DECIMAL(18,2),
		        @adjustSince1Start DECIMAL(18,2),
		        @adjustSince1End DECIMAL(18,2),
		        @adjustSince2Start DECIMAL(18,2),
		        @adjustSince2End DECIMAL(18,2),
		        @stockAt01Start DECIMAL(18,2),		
		        @stockAt01End DECIMAL(18,2),  		
		        @stockAt02Start DECIMAL(18,2),
		        @stockAt02End DECIMAL(18,2),
		        @received1 DECIMAL(18,2),
		        @received2 DECIMAL(18,2),
		        @available1 DECIMAL(18,2),
		        @available2 DECIMAL(18,2),
		        @usage1 DECIMAL(18,2),
		        @usage2 DECIMAL(18,2)
        SET @currentDate = GETDATE()
        SET @currentStock = (SELECT SUM(in_stock * cost) from [dbo].[inventory])
        SET @receivedSince1Start = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS [Total]
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('R','C','T') ) t WHERE [DateTime] BETWEEN @sDate1 AND @currentDate),2)),0)
        SET	@receivedSince1End = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS [Total]
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('R','C','T') ) t WHERE [DateTime] BETWEEN @eDate1 AND @currentDate),2)),0)
        SET @receivedSince2Start = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS [Total]
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('R','C','T') ) t WHERE [DateTime] BETWEEN @sDate2 AND @currentDate),2)),0)
        SET @receivedSince2End = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS [Total]
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('R','C','T') ) t WHERE [DateTime] BETWEEN @eDate2 AND @currentDate),2)),0)
        SET @stockMoveSince1Start = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('S','I','K','V')) t WHERE [DateTime] BETWEEN @sDate1 AND @currentDate),2)),0)
        SET @stockMoveSince1End =  ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('S','I','K','V')) t WHERE [DateTime] BETWEEN @eDate1 AND @currentDate),2)),0)
        SET @stockMoveSince2Start =  ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('S','I','K','V')) t WHERE [DateTime] BETWEEN @sDate2 AND @currentDate),2)),0)
        SET @stockMoveSince2End =  ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('S','I','K','V')) t WHERE [DateTime] BETWEEN @eDate2 AND @currentDate),2)),0)
        SET @adjustSince1Start = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('A','P','Z','Y')) t WHERE [DateTime] BETWEEN @sDate1 AND @currentDate),2)),0)
        SET @adjustSince1End = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('A','P','Z','Y')) t WHERE [DateTime] BETWEEN @eDate1 AND @currentDate),2)),0)
        SET @adjustSince2Start = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('A','P','Z','Y')) t WHERE [DateTime] BETWEEN @sDate2 AND @currentDate),2)),0)
        SET @adjustSince2End = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('A','P','Z','Y')) t WHERE [DateTime] BETWEEN @eDate2 AND @currentDate),2)),0)
        SET @stockAt01Start = @currentStock - @receivedSince1Start - @stockMoveSince1Start - @adjustSince1Start
        SET @stockAt01End = @currentStock - @receivedSince1End - @stockMoveSince1End - @adjustSince1End
        SET @stockAt02Start = @currentStock - @receivedSince2Start - @stockMoveSince2Start - @adjustSince2Start
        SET @stockAt02End = @currentStock - @receivedSince2End - @stockMoveSince2End - @adjustSince2End
        SET @received1 = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS [Total]
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('R','C','T') ) t WHERE [DateTime] BETWEEN @sDate1 AND @eDate1),2)),0)
        SET @received2 = ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS [Total]
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('R','C','T') ) t WHERE [DateTime] BETWEEN @sDate2 AND @eDate2),2)),0)
        SET @usage1 = @stockAt01Start + @received1 - @stockAt01End
        SET @usage2 = @stockAt02Start + @received2 - @stockAt02End
        SET @available1 = @stockAt01Start + @received1
        SET @available2 = @stockAt02Start + @received2
        SELECT
        'Total Sales' AS C1,
        ISNULL((ROUND((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE Status = 'C' And [DateTime] BETWEEN @sDate1 AND @eDate1),2)),0) AS C2,
        ISNULL((ROUND((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE Status = 'C' And [DateTime] BETWEEN @sDate2 AND @eDate2),2)),0) AS C3,
        ((ISNULL((ROUND((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE Status = 'C' And [DateTime] BETWEEN @sDate2 AND @eDate2),2)),0)) - (ISNULL((ROUND((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE Status = 'C' And [DateTime] BETWEEN @sDate1 AND @eDate1),2)),0))) AS C4,
        '001' As C5
        UNION
        SELECT
        'Beginning Inventory' AS C1,
        @stockAt01Start AS C2,
        @stockAt02Start AS C3,
        (@stockAt02Start - @stockAt01Start) AS C4,
        '002' As C5
        UNION
        SELECT
        'Received Items' AS C1,
        @received1 AS C2,
        @received2 AS C3,
        (@received2 - @received1) AS C4,
        '003' As C5
        UNION
        SELECT
        'Total Available' AS C1,
        @available1 AS C2,
        @available2 AS C3,
        (@available2 - @available1) AS C4,
        '004' As C5
        UNION
        SELECT
        'Stock Adjustments' AS C1,
        ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('A','P','Z','Y')) t WHERE [DateTime] BETWEEN @sDate1 AND @eDate1),2)),0) AS C2,
        ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('A','P','Z','Y')) t WHERE [DateTime] BETWEEN @sDate2 AND @eDate2),2)),0) AS C3,
        ((ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('A','P','Z','Y')) t WHERE [DateTime] BETWEEN @sDate2 AND @eDate2),2)),0)) - (ISNULL((ROUND((SELECT Sum(t.Total) FROM (SELECT Inventory.ItemNum, Inventory_In.[DateTime], Inventory_In.Quantity AS Qty, Inventory.Cost, Inventory_In.Quantity * Inventory.Cost AS Total
							        FROM Inventory_In INNER JOIN Inventory ON Inventory_In.ItemNum = Inventory.ItemNum WHERE Inventory_In.TransType IN ('A','P','Z','Y')) t WHERE [DateTime] BETWEEN @sDate1 AND @eDate1),2)),0))) AS C4,
        '005' As C5
        UNION
        SELECT
        'Ending Inventory' AS C1,
        @stockAt01End AS C2,
        @stockAt02End AS C3,
        (@stockAt02End - @stockAt01End) AS C4,
        '006' As C5
        UNION
        SELECT
        'Product Usage' AS C1,
        @usage1 AS C2,
        @usage2 AS C3,
        (@usage2 - @usage1) AS C4,
        '007' As C5
        ORDER BY C5
        SELECT
        'Cost of Goods Sold' AS C1,
        CASE
        WHEN @available1 = 0
        THEN 0 
        ELSE ROUND(ISNULL((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE [DateTime] BETWEEN @sDate1 AND @eDate1) / @available1 * 100,0),2)
        END AS C2,
        CASE 
        WHEN @available2 = 0
        THEN 0
        ELSE ROUND(ISNULL((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE [DateTime] BETWEEN @sDate2 AND @eDate2) /@available2 * 100 ,0),2) 
        END AS C3,
        CASE
        WHEN @available1 = 0 AND @available2 = 0
        THEN 0 
        WHEN @available1 = 0 
        THEN ROUND(ISNULL((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE [DateTime] BETWEEN @sDate2 AND @eDate2) /@available2 * 100 ,0),2) - 0 
        WHEN 
        @available2 = 0
        THEN 0 - ROUND(ISNULL((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE [DateTime] BETWEEN @sDate1 AND @eDate1) / @available1 * 100,0),2) 
        ELSE ROUND(ISNULL((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE [DateTime] BETWEEN @sDate2 AND @eDate2) /@available2 * 100 ,0),2) - ROUND(ISNULL((SELECT Sum([Grand_Total])  FROM [dbo].[Invoice_Totals] WHERE [DateTime] BETWEEN @sDate1 AND @eDate1) / @available1 * 100,0),2) 
        END AS C4,
        '001' As C5
        RETURN 
GO
/****** Object:  StoredProcedure [dbo].[Daily_Sales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Daily_Sales] (@PresentDate1 Datetime,@PresentDate2 DateTime,@LastDate1 DateTime,@LastDate2 DateTime) AS SELECT     storedescription, SUM(CurrentPTDActual) AS CurrentPTDActual, SUM(CurrentCustCount) AS CurrentCustCount, SUM(CompareCustCount) AS CompareCustCount, SUM(ComparePTDActual) AS ComparePTDActual, SUM(CurrentPTDGoal) AS CurrentPTDGoal, SUM(CurrentDailyGoal) AS CurrentDailyGoal, SUM(CompareDailyCustCount) AS CompareDailyCustCount, SUM(CompareDailyPTDActual) AS CompareDailyPTDActual, SUM(CurrentDailyCustCount) AS CurrentDailyCustCount, SUM(CurrentDailyPTDActual) AS CurrentDailyPTDActual FROM         (SELECT     storedescription, (CASE WHEN [Type] = 'Current' THEN SUM(totalsales) ELSE 0 END) AS CurrentPTDActual, (CASE WHEN [Type] = 'Current' THEN SUM(customers) ELSE 0 END) AS CurrentCustCount, (CASE WHEN [Type] = 'Compare' THEN SUM(customers) ELSE 0 END) AS CompareCustCount, (CASE WHEN [Type] = 'Compare' THEN SUM(totalsales) ELSE 0 END) AS ComparePTDActual, (CASE WHEN [Type] = 'Plan' THEN SUM(totalsales) ELSE 0 END) AS CurrentPTDGoal, (CASE WHEN [Type] = 'PlanDaily' THEN SUM(totalsales) ELSE 0 END) AS CurrentDailyGoal, (CASE WHEN [Type] = 'CompareDaily' THEN SUM(customers) ELSE 0 END) AS CompareDailyCustCount, (CASE WHEN [Type] = 'CompareDaily' THEN SUM(totalsales) ELSE 0 END) AS CompareDailyPTDActual, (CASE WHEN [Type] = 'CurrentDaily' THEN SUM(customers) ELSE 0 END) AS CurrentDailyCustCount, (CASE WHEN [Type] = 'CurrentDaily' THEN SUM(totalsales) ELSE 0 END) AS CurrentDailyPTDActual FROM          (SELECT     Setup_1.Store_ID + '  ' + Setup_1.Store_Description AS storedescription, ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'Current' AS type, COUNT(DISTINCT CC.Invoice_Number) AS customers FROM          Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS Inventory_1 INNER JOIN Departments AS Departments_1 INNER JOIN Setup AS Setup_1 ON Departments_1.Store_ID = Setup_1.Store_ID ON Inventory_1.Dept_ID = Departments_1.Dept_ID AND Inventory_1.Store_ID = Departments_1.Store_ID ON CC.ItemNum = Inventory_1.ItemNum AND CC.Store_ID = Inventory_1.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID WHERE      (I.Status = 'C') AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @PresentDate1 AND @PresentDate2) GROUP BY Setup_1.Store_ID, Setup_1.Store_Description UNION SELECT     Setup_1.Store_ID + '  ' + Setup_1.Store_Description AS storedescription, ROUND(SUM((CC.PricePer * CC.Quantity)  * (1 - I.Discount)), 3) AS totalsales, 'Compare' AS type, COUNT(DISTINCT CC.Invoice_Number) AS customers  FROM         Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS Inventory_1 INNER JOIN Departments AS Departments_1 INNER JOIN Setup AS Setup_1 ON Departments_1.Store_ID = Setup_1.Store_ID ON Inventory_1.Dept_ID = Departments_1.Dept_ID AND Inventory_1.Store_ID = Departments_1.Store_ID ON CC.ItemNum = Inventory_1.ItemNum AND CC.Store_ID = Inventory_1.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID  WHERE     (I.Status = 'C') AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @LastDate1 AND @lastDate2) GROUP BY Setup_1.Store_ID, Setup_1.Store_Description UNION SELECT     se.Store_ID + '  ' + se.Store_Description AS storedescription, SUM(bu.Goal_Amount) AS TotalSales, 'Plan' AS Type,  0 AS customers  FROM         Budget_Sales AS bu INNER JOIN Setup AS se ON bu.Store_ID = se.Store_ID  WHERE     (bu.DateTime BETWEEN @PresentDate1 AND @PresentDate2) GROUP BY se.Store_ID, se.Store_Description UNION SELECT     se.Store_ID + '  ' + se.Store_Description AS storedescription, SUM(bu.Goal_Amount) AS TotalSales, 'PlanDaily' AS Type, 0 AS customers  FROM         Budget_Sales AS bu INNER JOIN Setup AS se ON bu.Store_ID = se.Store_ID WHERE     (bu.DateTime = @PresentDate2) GROUP BY se.Store_ID, se.Store_Description UNION SELECT     Setup_1.Store_ID + '  ' + Setup_1.Store_Description AS storedescription, ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'CompareDaily' AS type, COUNT(DISTINCT CC.Invoice_Number) AS customers FROM         Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS Inventory_1 INNER JOIN Departments AS Departments_1 INNER JOIN Setup AS Setup_1 ON Departments_1.Store_ID = Setup_1.Store_ID ON Inventory_1.Dept_ID = Departments_1.Dept_ID AND Inventory_1.Store_ID = Departments_1.Store_ID ON CC.ItemNum = Inventory_1.ItemNum AND CC.Store_ID = Inventory_1.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID WHERE     (I.Status = 'C') AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime = @LastDate2) GROUP BY Setup_1.Store_ID, Setup_1.Store_Description UNION SELECT     Setup_1.Store_ID + '  ' + Setup_1.Store_Description AS storedescription, ROUND(SUM((CC.PricePer * CC.Quantity)  * (1 - I.Discount)), 3) AS totalsales, 'CurrentDaily' AS type, COUNT(DISTINCT CC.Invoice_Number) AS customers FROM         Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS Inventory_1 INNER JOIN Departments AS Departments_1 INNER JOIN Setup AS Setup_1 ON Departments_1.Store_ID = Setup_1.Store_ID ON Inventory_1.Dept_ID = Departments_1.Dept_ID AND Inventory_1.Store_ID = Departments_1.Store_ID ON CC.ItemNum = Inventory_1.ItemNum AND CC.Store_ID = Inventory_1.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID WHERE     (I.Status = 'C') AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime = @presentDate2) GROUP BY Setup_1.Store_ID, Setup_1.Store_Description) AS t1 GROUP BY storedescription, type) AS t2 GROUP BY storedescription
GO
/****** Object:  StoredProcedure [dbo].[DropTableIndexes]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[DropTableIndexes] AS SET NOCOUNT ON  DECLARE @IndexNames TABLE(IndexName nvarchar(256)) DECLARE @IndexCount int DECLARE @IndexName nvarchar(256)   INSERT @IndexNames (IndexName) SELECT o.name + '.' + i.name AS IndexName FROM sysindexes i, sysobjects o WHERE i.indid > 0 AND i.indid < 255 AND (i.status & 64) = 0 AND i.id = o.id AND o.type = 'U' AND OBJECTPROPERTY(o.id, 'IsSystemTable') =0 AND OBJECTPROPERTY(o.id, 'IsConstraint') = 0 AND o.name NOT LIKE '%Mobile_%'   SELECT @IndexCount = Count(*) FROM @IndexNames  WHILE @IndexCount > 0 BEGIN SET @IndexName = NULL  SELECT @IndexName = MIN(IndexName) FROM @IndexNames  IF @IndexName <> 'NxT_Version.PK_NxT_Version' BEGIN EXECUTE('DROP INDEX ' + @IndexName) PRINT ' Dropping Index ' + @IndexName END   DELETE FROM @IndexNames WHERE IndexName = @IndexName  SET @IndexCount = @IndexCount - 1 END SET NOCOUNT OFF
GO
/****** Object:  StoredProcedure [dbo].[get_clockin_employee_details]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 

create procedure [dbo].[get_clockin_employee_details]
	@storeId varchar(10)

   as
		-- get invoice totals

	Select case when ( IsNull(First_Name, '') <> '' AND isnull(Last_Name,'') <> '')  then  IsNull(First_Name,'')+' ' + isnull(Middle_Name,'')+ ' ' +isnull(Last_Name,'') else IsNull(EmpName , '' ) end As employee_name ,
		Replace(ej.JobCodeID,e.Orig_Store_ID,'') As job,
		(CONVERT(varchar, t.StartDateTime, 101) + ' ' +CONVERT(varchar, t.StartDateTime, 108))as clocked_intime
		into #Employee_ClockIn_Description
		 
		From Employee_JobCode ej  Right join Employee e
		inner join Time_Clock t on t.Cashier_ID=e.Cashier_ID and t.Store_ID=e.Orig_Store_ID
		on e.Cashier_ID = ej.Cashier_ID  where  t.EndDateTime IS NULL And t.store_id = @storeId


	select * from #Employee_ClockIn_Description 
GO
/****** Object:  StoredProcedure [dbo].[get_CRE_WeeklyDepartmentSales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[get_CRE_WeeklyDepartmentSales]

@storeid varchar(10),
@lodate datetime,
@depts varchar(1000)

as
set nocount on

declare @temptable1 as table
(
 store_id nvarchar(48),
 Dept_ID nvarchar(36),
 Description nvarchar(100),
 OrigCost decimal(10,2),
 LinePrice decimal(10,2),
Dimension nvarchar(36)
 
 
)

declare @temptable2 as table
( 
store_id nvarchar(48),
 Dept_ID nvarchar(36),
 Description nvarchar(100),
 OrigCost1 decimal(10,2),
 LinePrice1 decimal(10,2),
 OrigCost2 decimal(10,2),
 LinePrice2 decimal(10,2) ,
 OrigCost3 decimal(10,2),
 LinePrice3 decimal(10,2),
 OrigCost4 decimal(10,2),
 LinePrice4 decimal(10,2),
 OrigCost5 decimal(10,2),
 LinePrice5 decimal(10,2),
 OrigCost6 decimal(10,2),
 LinePrice6 decimal(10,2),
 OrigCost7 decimal(10,2),
 LinePrice7 decimal(10,2)







)

Insert into @temptable1 select tmp.* From (Select  departments.Store_ID, departments.Dept_ID , departments.Description, IsNull(sum(temp.origCost),0) as OrigCost,IsNull(sum(temp.LinePrice),0) as LinePrice,'DAY1' As Dimension 
                  from (SELECT  Invoice_Itemized.ItemNum, Invoice_totals.Store_id ,Sum(Invoice_Itemized.Quantity * inventory.Cost)
                  As OrigCost, 
                  ROUND(SUM(Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold)) * (CASE WHEN (((Invoice_Itemized.ItemNum='GIFT_C' AND Gift_Card_Trans.InitiatedByReturn=0)
                  Or Invoice_Itemized.ItemNum<>'GIFT_C') and Invoice_Itemized.Returned=0 ) 
                  THEN (1 - Invoice_Totals.Discount)ELSE 1 END),2) AS LinePrice, (CASE WHEN 1 - Invoice_Itemized.LineDisc = 0  
                  THEN ROUND((CASE WHEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) <> 0 
                  THEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) 
                  ELSE SUM(Quantity * ROUND((OrigPricePer+GC_Sold+Invoice_Itemized.Liability),2)) END) * (1 - Invoice_Totals.Discount), 2)
                  ELSE SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2)) -ROUND((SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2))) * (1 - Invoice_Itemized.LineDisc) , 2) END) AS DiscAmt 
                  FROM Invoice_Itemized INNER JOIN Inventory on inventory.ItemNum=invoice_itemized.ItemNum and inventory.Store_ID=Invoice_Itemized.Store_ID inner join Invoice_Totals
                  ON Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID AND Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number 
                  LEFT JOIN Gift_Card_Trans on Gift_Card_Trans.Invoice_Number = Invoice_Totals.Invoice_Number AND Invoice_Itemized.LineNum = (Gift_Card_Trans.LineNum+1) 
                  WHERE Invoice_Totals.Status = 'C'  and (Invoice_Totals.datetime between CONVERT(VARCHAR(10), @lodate, 101) + ' 12:00:00 AM' and CONVERT(VARCHAR(10), @lodate, 101) +' 11:59:59 PM' and Invoice_Totals.Store_ID = @storeid)
                  GROUP BY   Invoice_Itemized.LineNum, Invoice_Itemized.Quantity, Invoice_Itemized.ItemNum,   Invoice_totals.Store_id,
                  Invoice_Itemized.GC_Sold, Invoice_Totals.Discount, Invoice_Itemized.LineDisc,Invoice_Itemized.Returned,Gift_Card_Trans.InitiatedByReturn) AS temp
                  Inner join inventory on temp.Store_ID=inventory.Store_ID and inventory.ItemNum = temp.ItemNum right join departments on Departments.Store_ID = departments.Store_ID and departments.Dept_ID = inventory.Dept_ID
				  where Departments.Store_ID = @storeid 
                  group by departments.Dept_ID ,departments.Description, Departments.Store_ID
				  
				  				  
				  union

				  Select  departments.Store_ID, departments.Dept_ID , departments.Description, IsNull(sum(temp.origCost),0) as OrigCost,IsNull(sum(temp.LinePrice),0) as LinePrice,'DAY2' As Dimension 
                  from (SELECT  Invoice_Itemized.ItemNum, Invoice_totals.Store_id ,Sum(Invoice_Itemized.Quantity * inventory.Cost)
                  As OrigCost, 
                  ROUND(SUM(Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold)) * (CASE WHEN (((Invoice_Itemized.ItemNum='GIFT_C' AND Gift_Card_Trans.InitiatedByReturn=0)
                  Or Invoice_Itemized.ItemNum<>'GIFT_C') and Invoice_Itemized.Returned=0 ) 
                  THEN (1 - Invoice_Totals.Discount)ELSE 1 END),2) AS LinePrice, (CASE WHEN 1 - Invoice_Itemized.LineDisc = 0  
                  THEN ROUND((CASE WHEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) <> 0 
                  THEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) 
                  ELSE SUM(Quantity * ROUND((OrigPricePer+GC_Sold+Invoice_Itemized.Liability),2)) END) * (1 - Invoice_Totals.Discount), 2)
                  ELSE SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2)) -ROUND((SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2))) * (1 - Invoice_Itemized.LineDisc) , 2) END) AS DiscAmt 
                  FROM Invoice_Itemized INNER JOIN Inventory on inventory.ItemNum=invoice_itemized.ItemNum and inventory.Store_ID=Invoice_Itemized.Store_ID inner join Invoice_Totals
                  ON Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID AND Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number 
                  LEFT JOIN Gift_Card_Trans on Gift_Card_Trans.Invoice_Number = Invoice_Totals.Invoice_Number AND Invoice_Itemized.LineNum = (Gift_Card_Trans.LineNum+1) 
                  WHERE Invoice_Totals.Status = 'C' and (Invoice_Totals.datetime between CONVERT(VARCHAR(10), DATEADD(DAY, 1, @lodate), 101) + ' 12:00:00 AM' and CONVERT(VARCHAR(10),  DATEADD(DAY, 1, @lodate), 101) +' 11:59:59 PM' and Invoice_Totals.Store_ID = @storeid)
                  GROUP BY   Invoice_Itemized.LineNum, Invoice_Itemized.Quantity, Invoice_Itemized.ItemNum,   Invoice_totals.Store_id,
                  Invoice_Itemized.GC_Sold, Invoice_Totals.Discount, Invoice_Itemized.LineDisc,Invoice_Itemized.Returned,Gift_Card_Trans.InitiatedByReturn) AS temp
                  Inner join inventory on temp.Store_ID=inventory.Store_ID and inventory.ItemNum = temp.ItemNum right join departments on Departments.Store_ID = departments.Store_ID and departments.Dept_ID = inventory.Dept_ID
				  where Departments.Store_ID = @storeid
                  group by departments.Dept_ID ,departments.Description, Departments.Store_ID
				  



				  union

				  Select  departments.Store_ID, departments.Dept_ID , departments.Description, IsNull(sum(temp.origCost),0) as OrigCost,IsNull(sum(temp.LinePrice),0) as LinePrice,'DAY3' As Dimension 
                  from (SELECT  Invoice_Itemized.ItemNum, Invoice_totals.Store_id ,Sum(Invoice_Itemized.Quantity * inventory.Cost)
                  As OrigCost, 
                  ROUND(SUM(Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold)) * (CASE WHEN (((Invoice_Itemized.ItemNum='GIFT_C' AND Gift_Card_Trans.InitiatedByReturn=0)
                  Or Invoice_Itemized.ItemNum<>'GIFT_C') and Invoice_Itemized.Returned=0 ) 
                  THEN (1 - Invoice_Totals.Discount)ELSE 1 END),2) AS LinePrice, (CASE WHEN 1 - Invoice_Itemized.LineDisc = 0  
                  THEN ROUND((CASE WHEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) <> 0 
                  THEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) 
                  ELSE SUM(Quantity * ROUND((OrigPricePer+GC_Sold+Invoice_Itemized.Liability),2)) END) * (1 - Invoice_Totals.Discount), 2)
                  ELSE SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2)) -ROUND((SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2))) * (1 - Invoice_Itemized.LineDisc) , 2) END) AS DiscAmt 
                  FROM Invoice_Itemized INNER JOIN Inventory on inventory.ItemNum=invoice_itemized.ItemNum and inventory.Store_ID=Invoice_Itemized.Store_ID inner join Invoice_Totals
                  ON Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID AND Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number 
                  LEFT JOIN Gift_Card_Trans on Gift_Card_Trans.Invoice_Number = Invoice_Totals.Invoice_Number AND Invoice_Itemized.LineNum = (Gift_Card_Trans.LineNum+1) 
                  WHERE Invoice_Totals.Status = 'C' and (Invoice_Totals.datetime between CONVERT(VARCHAR(10),DATEADD(DAY, 2, @lodate), 101) + ' 12:00:00 AM' and CONVERT(VARCHAR(10), DATEADD(DAY, 2, @lodate), 101) +' 11:59:59 PM' and Invoice_Totals.Store_ID = @storeid)
                  GROUP BY   Invoice_Itemized.LineNum, Invoice_Itemized.Quantity, Invoice_Itemized.ItemNum,   Invoice_totals.Store_id,
                  Invoice_Itemized.GC_Sold, Invoice_Totals.Discount, Invoice_Itemized.LineDisc,Invoice_Itemized.Returned,Gift_Card_Trans.InitiatedByReturn) AS temp
                  Inner join inventory on temp.Store_ID=inventory.Store_ID and inventory.ItemNum = temp.ItemNum right join departments on Departments.Store_ID = departments.Store_ID and departments.Dept_ID = inventory.Dept_ID
				  where Departments.Store_ID = @storeid
                  group by departments.Dept_ID ,departments.Description, Departments.Store_ID
				  

				  
				  union

				  Select  departments.Store_ID, departments.Dept_ID , departments.Description, IsNull(sum(temp.origCost),0) as OrigCost,IsNull(sum(temp.LinePrice),0) as LinePrice,'DAY4' As Dimension 
                  from (SELECT  Invoice_Itemized.ItemNum, Invoice_totals.Store_id ,Sum(Invoice_Itemized.Quantity * inventory.Cost)
                  As OrigCost, 
                  ROUND(SUM(Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold)) * (CASE WHEN (((Invoice_Itemized.ItemNum='GIFT_C' AND Gift_Card_Trans.InitiatedByReturn=0)
                  Or Invoice_Itemized.ItemNum<>'GIFT_C') and Invoice_Itemized.Returned=0 ) 
                  THEN (1 - Invoice_Totals.Discount)ELSE 1 END),2) AS LinePrice, (CASE WHEN 1 - Invoice_Itemized.LineDisc = 0  
                  THEN ROUND((CASE WHEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) <> 0 
                  THEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) 
                  ELSE SUM(Quantity * ROUND((OrigPricePer+GC_Sold+Invoice_Itemized.Liability),2)) END) * (1 - Invoice_Totals.Discount), 2)
                  ELSE SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2)) -ROUND((SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2))) * (1 - Invoice_Itemized.LineDisc) , 2) END) AS DiscAmt 
                  FROM Invoice_Itemized INNER JOIN Inventory on inventory.ItemNum=invoice_itemized.ItemNum and inventory.Store_ID=Invoice_Itemized.Store_ID inner join Invoice_Totals
                  ON Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID AND Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number 
                  LEFT JOIN Gift_Card_Trans on Gift_Card_Trans.Invoice_Number = Invoice_Totals.Invoice_Number AND Invoice_Itemized.LineNum = (Gift_Card_Trans.LineNum+1) 
                  WHERE Invoice_Totals.Status = 'C' and (Invoice_Totals.datetime between CONVERT(VARCHAR(10), DATEADD(DAY, 3, @lodate), 101) + ' 12:00:00 AM' and CONVERT(VARCHAR(10),DATEADD(DAY, 3, @lodate), 101) +' 11:59:59 PM' and Invoice_Totals.Store_ID = @storeid)
                  GROUP BY   Invoice_Itemized.LineNum, Invoice_Itemized.Quantity, Invoice_Itemized.ItemNum,   Invoice_totals.Store_id,
                  Invoice_Itemized.GC_Sold, Invoice_Totals.Discount, Invoice_Itemized.LineDisc,Invoice_Itemized.Returned,Gift_Card_Trans.InitiatedByReturn) AS temp
                  Inner join inventory on temp.Store_ID=inventory.Store_ID and inventory.ItemNum = temp.ItemNum right join departments on Departments.Store_ID = departments.Store_ID and departments.Dept_ID = inventory.Dept_ID
				  where Departments.Store_ID = @storeid
                  group by departments.Dept_ID ,departments.Description, Departments.Store_ID



				  union

				  Select  departments.Store_ID, departments.Dept_ID , departments.Description, IsNull(sum(temp.origCost),0) as OrigCost,IsNull(sum(temp.LinePrice),0) as LinePrice,'DAY5' As Dimension 
                  from (SELECT  Invoice_Itemized.ItemNum, Invoice_totals.Store_id ,Sum(Invoice_Itemized.Quantity * inventory.Cost)
                  As OrigCost, 
                  ROUND(SUM(Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold)) * (CASE WHEN (((Invoice_Itemized.ItemNum='GIFT_C' AND Gift_Card_Trans.InitiatedByReturn=0)
                  Or Invoice_Itemized.ItemNum<>'GIFT_C') and Invoice_Itemized.Returned=0 ) 
                  THEN (1 - Invoice_Totals.Discount)ELSE 1 END),2) AS LinePrice, (CASE WHEN 1 - Invoice_Itemized.LineDisc = 0  
                  THEN ROUND((CASE WHEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) <> 0 
                  THEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) 
                  ELSE SUM(Quantity * ROUND((OrigPricePer+GC_Sold+Invoice_Itemized.Liability),2)) END) * (1 - Invoice_Totals.Discount), 2)
                  ELSE SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2)) -ROUND((SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2))) * (1 - Invoice_Itemized.LineDisc) , 2) END) AS DiscAmt 
                  FROM Invoice_Itemized INNER JOIN Inventory on inventory.ItemNum=invoice_itemized.ItemNum and inventory.Store_ID=Invoice_Itemized.Store_ID inner join Invoice_Totals
                  ON Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID AND Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number 
                  LEFT JOIN Gift_Card_Trans on Gift_Card_Trans.Invoice_Number = Invoice_Totals.Invoice_Number AND Invoice_Itemized.LineNum = (Gift_Card_Trans.LineNum+1) 
                  WHERE Invoice_Totals.Status = 'C' and (Invoice_Totals.datetime between CONVERT(VARCHAR(10), DATEADD(DAY, 4, @lodate), 101) + ' 12:00:00 AM' and CONVERT(VARCHAR(10), DATEADD(DAY, 4, @lodate), 101) +' 11:59:59 PM' and Invoice_Totals.Store_ID = @storeid)
                  GROUP BY   Invoice_Itemized.LineNum, Invoice_Itemized.Quantity, Invoice_Itemized.ItemNum,   Invoice_totals.Store_id,
                  Invoice_Itemized.GC_Sold, Invoice_Totals.Discount, Invoice_Itemized.LineDisc,Invoice_Itemized.Returned,Gift_Card_Trans.InitiatedByReturn) AS temp
                  Inner join inventory on temp.Store_ID=inventory.Store_ID and inventory.ItemNum = temp.ItemNum right join departments on Departments.Store_ID = departments.Store_ID and departments.Dept_ID = inventory.Dept_ID
				  where Departments.Store_ID = @storeid
                  group by departments.Dept_ID ,departments.Description, Departments.Store_ID
				  
				  
				  
				  union

				  Select  departments.Store_ID, departments.Dept_ID , departments.Description, IsNull(sum(temp.origCost),0) as OrigCost,IsNull(sum(temp.LinePrice),0) as LinePrice,'DAY6' As Dimension 
                  from (SELECT  Invoice_Itemized.ItemNum, Invoice_totals.Store_id ,Sum(Invoice_Itemized.Quantity * inventory.Cost)
                  As OrigCost, 
                  ROUND(SUM(Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold)) * (CASE WHEN (((Invoice_Itemized.ItemNum='GIFT_C' AND Gift_Card_Trans.InitiatedByReturn=0)
                  Or Invoice_Itemized.ItemNum<>'GIFT_C') and Invoice_Itemized.Returned=0 ) 
                  THEN (1 - Invoice_Totals.Discount)ELSE 1 END),2) AS LinePrice, (CASE WHEN 1 - Invoice_Itemized.LineDisc = 0  
                  THEN ROUND((CASE WHEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) <> 0 
                  THEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) 
                  ELSE SUM(Quantity * ROUND((OrigPricePer+GC_Sold+Invoice_Itemized.Liability),2)) END) * (1 - Invoice_Totals.Discount), 2)
                  ELSE SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2)) -ROUND((SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2))) * (1 - Invoice_Itemized.LineDisc) , 2) END) AS DiscAmt 
                  FROM Invoice_Itemized INNER JOIN Inventory on inventory.ItemNum=invoice_itemized.ItemNum and inventory.Store_ID=Invoice_Itemized.Store_ID inner join Invoice_Totals
                  ON Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID AND Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number 
                  LEFT JOIN Gift_Card_Trans on Gift_Card_Trans.Invoice_Number = Invoice_Totals.Invoice_Number AND Invoice_Itemized.LineNum = (Gift_Card_Trans.LineNum+1) 
                  WHERE Invoice_Totals.Status = 'C' and (Invoice_Totals.datetime between CONVERT(VARCHAR(10), DATEADD(DAY, 5, @lodate), 101) + ' 12:00:00 AM' and CONVERT(VARCHAR(10), DATEADD(DAY, 5, @lodate), 101) +' 11:59:59 PM' and Invoice_Totals.Store_ID = @storeid)
                  GROUP BY   Invoice_Itemized.LineNum, Invoice_Itemized.Quantity, Invoice_Itemized.ItemNum,   Invoice_totals.Store_id,
                  Invoice_Itemized.GC_Sold, Invoice_Totals.Discount, Invoice_Itemized.LineDisc,Invoice_Itemized.Returned,Gift_Card_Trans.InitiatedByReturn) AS temp
                  Inner join inventory on temp.Store_ID=inventory.Store_ID and inventory.ItemNum = temp.ItemNum right join departments on Departments.Store_ID = departments.Store_ID and departments.Dept_ID = inventory.Dept_ID
				  where Departments.Store_ID = @storeid
                  group by departments.Dept_ID ,departments.Description, Departments.Store_ID
				  

				  union

				  Select  departments.Store_ID, departments.Dept_ID , departments.Description, IsNull(sum(temp.origCost),0) as OrigCost,IsNull(sum(temp.LinePrice),0) as LinePrice,'DAY7' As Dimension 
                  from (SELECT  Invoice_Itemized.ItemNum, Invoice_totals.Store_id ,Sum(Invoice_Itemized.Quantity * inventory.Cost)
                  As OrigCost, 
                  ROUND(SUM(Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold)) * (CASE WHEN (((Invoice_Itemized.ItemNum='GIFT_C' AND Gift_Card_Trans.InitiatedByReturn=0)
                  Or Invoice_Itemized.ItemNum<>'GIFT_C') and Invoice_Itemized.Returned=0 ) 
                  THEN (1 - Invoice_Totals.Discount)ELSE 1 END),2) AS LinePrice, (CASE WHEN 1 - Invoice_Itemized.LineDisc = 0  
                  THEN ROUND((CASE WHEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) <> 0 
                  THEN SUM(Quantity * ROUND((PricePer+GC_Sold+Invoice_Itemized.Liability),2)) 
                  ELSE SUM(Quantity * ROUND((OrigPricePer+GC_Sold+Invoice_Itemized.Liability),2)) END) * (1 - Invoice_Totals.Discount), 2)
                  ELSE SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2)) -ROUND((SUM(Quantity * ROUND((Invoice_Itemized.OrigPricePer + Invoice_Itemized.GC_Sold + Invoice_Itemized.Liability) * (1 - Invoice_Totals.Discount), 2))) * (1 - Invoice_Itemized.LineDisc) , 2) END) AS DiscAmt 
                  FROM Invoice_Itemized INNER JOIN Inventory on inventory.ItemNum=invoice_itemized.ItemNum and inventory.Store_ID=Invoice_Itemized.Store_ID inner join Invoice_Totals
                  ON Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID AND Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number 
                  LEFT JOIN Gift_Card_Trans on Gift_Card_Trans.Invoice_Number = Invoice_Totals.Invoice_Number AND Invoice_Itemized.LineNum = (Gift_Card_Trans.LineNum+1) 
                  WHERE Invoice_Totals.Status = 'C' and (Invoice_Totals.datetime between CONVERT(VARCHAR(10), DATEADD(DAY, 6, @lodate), 101)+ ' 12:00:00 AM' and CONVERT(VARCHAR(10), DATEADD(DAY, 6, @lodate), 101)+' 11:59:59 PM' and Invoice_Totals.Store_ID = @storeid)
                  GROUP BY   Invoice_Itemized.LineNum, Invoice_Itemized.Quantity, Invoice_Itemized.ItemNum,   Invoice_totals.Store_id,
                  Invoice_Itemized.GC_Sold, Invoice_Totals.Discount, Invoice_Itemized.LineDisc,Invoice_Itemized.Returned,Gift_Card_Trans.InitiatedByReturn) AS temp
                  Inner join inventory on temp.Store_ID=inventory.Store_ID and inventory.ItemNum = temp.ItemNum right join departments on Departments.Store_ID = departments.Store_ID and departments.Dept_ID = inventory.Dept_ID
				  where Departments.Store_ID = @storeid
                  group by departments.Dept_ID ,departments.Description, Departments.Store_ID
				  

				  
				  ) As tmp

If Exists(select * from @temptable1) 
Begin
Insert into @temptable2(store_id,  Dept_ID , Description) Select Distinct store_id,Dept_ID , Description from  @temptable1
	update @temptable2
		set OrigCost1 =0,LinePrice1 = 0,OrigCost2 =0,LinePrice2 = 0
	update @temptable2
		set OrigCost1 =t1.OrigCost,
		LinePrice1=T1.LinePrice					
		from @temptable1 t1, @temptable2 t2
		where t1.Dept_ID =t2.Dept_ID and t1.store_id = t2.store_id and t1.Dimension='DAY1'

		update @temptable2
		set OrigCost2 =t1.OrigCost,
		LinePrice2=T1.LinePrice					
		from @temptable1 t1, @temptable2 t2
		where t1.Dept_ID =t2.Dept_ID and t1.store_id = t2.store_id and t1.Dimension='DAY2'


		update @temptable2
		set OrigCost3 =t1.OrigCost,
		LinePrice3=T1.LinePrice					
		from @temptable1 t1, @temptable2 t2
		where t1.Dept_ID =t2.Dept_ID and t1.store_id = t2.store_id and t1.Dimension='DAY3'


		update @temptable2
		set OrigCost4 =t1.OrigCost,
		LinePrice4=T1.LinePrice					
		from @temptable1 t1, @temptable2 t2
		where t1.Dept_ID =t2.Dept_ID and t1.store_id = t2.store_id and t1.Dimension='DAY4'

		update @temptable2
		set OrigCost5 =t1.OrigCost,
		LinePrice5=T1.LinePrice					
		from @temptable1 t1, @temptable2 t2
		where t1.Dept_ID =t2.Dept_ID and t1.store_id = t2.store_id and t1.Dimension='DAY5'


update @temptable2
		set OrigCost6 =t1.OrigCost,
		LinePrice6=T1.LinePrice					
		from @temptable1 t1, @temptable2 t2
		where t1.Dept_ID =t2.Dept_ID and t1.store_id = t2.store_id and t1.Dimension='DAY6'



update @temptable2
		set OrigCost7 =t1.OrigCost,
		LinePrice7=T1.LinePrice					
		from @temptable1 t1, @temptable2 t2
		where t1.Dept_ID =t2.Dept_ID and t1.store_id = t2.store_id and t1.Dimension='DAY7'
End
--Else
--Begin
--Insert into @temptable2 values(@storeid ,'','',0,0,0,0,0,0,0,0,0,0,0,0,0,0)
--End
IF LEN(ISNULL(@depts, '')) = 0 
begin
select * from  @temptable2
end
Else
Begin
DECLARE @xml xml;

     set @xml = N'<root><r>' + replace(@depts,',','</r><r>') + '</r></root>'

				  select * from  @temptable2 where dept_id IN(select t.value('.','varchar(max)') 
                            from @xml.nodes('//root/r') as a(t) )
End

 

         set nocount off  
GO
/****** Object:  StoredProcedure [dbo].[get_daily_comparison]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[get_daily_comparison]
    @storeId varchar(10),
	@lodate varchar(10),
	@hidate varchar(10)
as
	set nocount on

	-- get invoice totals
	select 
		@storeId as store_id,
		convert(varchar(4),DatePart(year,[datetime])) + '-' 
			+ REPLACE(STR(DATEPART(MONTH,[datetime]),2),' ','0') + '-'
			+ REPLACE(STR(DATEPART(day,[datetime]),2),' ','0') 			
			as date_key,
		sum(total_price)as total_price,
		sum(total_cost) as total_cost,
		convert(decimal(12,2),0) as gross_profit,
		convert(decimal(12,2),0) as profit_margin,
		convert(decimal(12,2),0) as labor_cost,
		convert(decimal(12,2),0) as labor_sales,
		convert(decimal(12,2),0) as labor_minutes
	 into #invoice_totals			
	 from Invoice_Totals 
		where 
			store_id = @storeId
			 and  [Status]='C'
			and 

			((convert(varchar(4),DatePart(year,[datetime])) + '-' 
				+ REPLACE(STR(DATEPART(MONTH,[datetime]),2),' ','0') + '-'
				+ REPLACE(STR(DATEPART(day,[datetime]),2),' ','0') = @lodate )
			or
			(convert(varchar(4),DatePart(year,[datetime])) + '-' 
				+ REPLACE(STR(DATEPART(MONTH,[datetime]),2),' ','0') + '-'
				+ REPLACE(STR(DATEPART(day,[datetime]),2),' ','0') = @hidate )
				)
		group by DatePart(year,[datetime]), DATEPART(month,[datetime]), DATEPART(day,[datetime])
	
	-- add in labor totals
	select
			@storeId as store_id,
			convert(varchar(4),DatePart(year,[StartDateTime])) + '-' 
			+ REPLACE(STR(DATEPART(MONTH,[StartDateTime]),2),' ','0') + '-'
			+ REPLACE(STR(DATEPART(day,[StartDateTime]),2),' ','0') 			
			as date_key,
			sum(numMinutes) as NumMinutes,
			sum(wages) as Wages
	into #time_clock
	from Time_Clock	
	where 
		store_id = @storeId
		and
			(convert(varchar(4),DatePart(year,[StartDateTime])) + '-' 
				+ REPLACE(STR(DATEPART(MONTH,[StartDateTime]),2),' ','0') + '-'
				+ REPLACE(STR(DATEPART(day,[StartDateTime]),2),' ','0') = @lodate)
			or
			(convert(varchar(4),DatePart(year,[StartDateTime])) + '-' 
				+ REPLACE(STR(DATEPART(MONTH,[StartDateTime]),2),' ','0') + '-'
				+ REPLACE(STR(DATEPART(day,[StartDateTime]),2),' ','0') = @hidate)
	group by DatePart(year,[StartDateTime]), DATEPART(month,[StartDateTime]), DATEPART(day,[StartDateTime])

	
	update #invoice_totals
		set labor_cost = t.Wages,
		    labor_sales = round((t.wages / i.total_price)*100,2), 
			labor_minutes = t.NumMinutes
		from #invoice_totals i, #time_clock t
		where i.date_key = t.date_key


		update #invoice_totals set gross_profit= total_price-total_cost , profit_margin = round(((total_price-total_cost)/total_price)*100,2) 
		
		select * from #invoice_totals order by date_key

	set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_daily_sales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[get_daily_sales]
    @storeId varchar(10),
	@hidate datetime
as
	set 

nocount on

Declare @datelowrange  nvarchar(20)
Declare @datehighRange nvarchar(20)

set @datelowrange = @hidate + ' 12:00:00 AM'
set @datehighrange = @hidate + ' 11:59:59 PM'


	-- get invoice totals
	select 
		@storeId as store_id,
		
 REPLACE(STR(DATEPART(HOUR,[datetime]),2),' ','0') +':00:00'
			as date_key,
		sum(total_price)as 

total_price,
		sum(total_cost) as total_cost,
		convert(decimal(12,2),0) as labor_cost,
		convert

(decimal(12,2),0) as labor_minutes ,'' as datastatus
	 into #invoice_totals			
	 from Invoice_Totals 
	 where 

store_id = @storeId
			and 
			([datetime] between @datelowrange and @datehighRange)

		group by DatePart(year,[datetime]), DATEPART(month,[datetime]) , DATEPART(DAY,[datetime]), DATEPART(HOUR,[datetime])
	

-- add in labor totals
	select
			
 REPLACE(STR(DATEPART(HOUR,[StartDateTime]),2),' ','0') +':00:00'
			as date_key,
			sum(numMinutes) as NumMinutes,
			

sum(wages) as Wages
	into #time_clock
	from Time_Clock	
	group by DatePart(year,[StartDateTime]), DATEPART

(month,[StartDateTime]),DATEPART(DAY,[StartDateTime]),DATEPART(HOUR,[StartDateTime])

	
	update #invoice_totals
		set labor_cost = t.Wages,
	

		labor_minutes = t.NumMinutes
		from #invoice_totals i, #time_clock t
		where i.date_key = 

t.date_key

	select * from #invoice_totals order by date_key

	set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_dailysales_comparison]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
Create Procedure [dbo].[get_dailysales_comparison]

@storeid varchar(10),
@lodate datetime,
@hidate datetime

as
set nocount on

declare @temptable1 as table
(
 store_id nvarchar(48),
 date_key nvarchar(36),
 total_price decimal,
  total_cost decimal,
 labor_cost decimal,
 labor_minutes  decimal,
 datastatus nvarchar(10) 
 
)

declare @temptable2 as table
( 
store_id nvarchar(48),
date_key nvarchar(36),
total_price decimal,
total_cost decimal,
labor_cost decimal,
labor_minutes decimal,
datastatus nvarchar(10)
)
Insert into @temptable1
EXEC [dbo].get_daily_sales @storeid, @hidate 


Insert into @temptable2
Exec [dbo].get_daily_sales  @storeid,  @lodate

update @temptable1 set datastatus='current'

update @temptable2 set datastatus='prev'



Select * from @temptable2
UNION
Select * from @temptable1
Order by date_key


set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_daterange_sales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[get_daterange_sales]
    @storeId varchar(10),
	@lodate varchar(10),
	@hidate varchar(10)
as
	set nocount on

	-- get invoice totals
	select 
		@storeId as store_id,
		sum(total_price)as total_price,
		sum(total_cost) as total_cost,
		convert(decimal(12,2),0) as labor_cost,
		convert(decimal(12,2),0) as labor_minutes
	 into #invoice_totals			
	 from Invoice_Totals 
	 where store_id = @storeId
			and 
				(convert(varchar(4),DatePart(year,[datetime])) + '-' 
				+ REPLACE(STR(DATEPART(MONTH,[datetime]),2),' ','0') + '-'
				+ REPLACE(STR(DATEPART(day,[datetime]),2),' ','0')
				 >= @lodate)
			and
				(convert(varchar(4),DatePart(year,[datetime])) + '-' 
				+ REPLACE(STR(DATEPART(month,[datetime]),2),' ','0') + '-' 
				+ REPLACE(STR(DATEPART(day,[datetime]),2),' ','0') <= @hidate)


	-- add in labor totals
	select
			sum(numMinutes) as NumMinutes,
			sum(wages) as Wages
	into #time_clock
	from Time_Clock	
	where  store_id = @storeId
			and 
				(convert(varchar(4),DatePart(year,StartDateTime)) + '-' 
				+ REPLACE(STR(DATEPART(MONTH,StartDateTime),2),' ','0') + '-'
				+ REPLACE(STR(DATEPART(day,StartDateTime),2),' ','0')
				 >= @lodate)
			and
				(convert(varchar(4),DatePart(year,StartDateTime)) + '-' 
				+ REPLACE(STR(DATEPART(month,StartDateTime),2),' ','0') + '-' 
				+ REPLACE(STR(DATEPART(day,StartDateTime),2),' ','0') <= @hidate)

	group by Store_ID

	
	update #invoice_totals
		set labor_cost = t.Wages,
			labor_minutes = t.NumMinutes
		from #invoice_totals i, #time_clock t


	select *, @lodate as lodate, @hidate as hidate from #invoice_totals 

	set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_daterange_totalsales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[get_daterange_totalsales] @storeId varchar(10),
@lodate nvarchar(20),
@hidate nvarchar(20),
@dimension Nvarchar(10) = Null
AS
  SET

  NOCOUNT ON
  If @dimension is Null
  Begin
  SET @dimension =
                  CASE
                    WHEN @lodate LIKE '[1-2][0-9][0-9][0-9]-[0-1][0-9]' THEN 'monthly'
					WHEN @lodate LIKE '[1-2][0-9][0-9][0-9]' THEN 'yearly'
                    WHEN @lodate LIKE '[1-2][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]' THEN 'daily'
                    ELSE 'hourly'
                  END
  End

  
  IF @dimension = 'hourly'
  BEGIN
    SET @lodate = CONVERT(char(10), @lodate, 126)
    SET @hidate = CONVERT(char(10), @hidate, 126)
  END


  DECLARE @lodatevar nvarchar(30)
  DECLARE @hidatevar nvarchar(30)

  SET @lodatevar =
                  CASE
                    WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), @lodate, 126)
                    WHEN @dimension = 'hourly' THEN @hidate + ' 00:00:00.00'
					WHEN @dimension = 'yearly' THEN  @lodate
					ELSE CONVERT(char(10), @lodate, 126)
                  END

  SET @hidatevar =
                  CASE
                    WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), @hidate, 126)
                    WHEN @dimension = 'hourly' THEN @hidate + ' 23:59:59.99'
					WHEN @dimension = 'yearly' THEN  @hidate
                    ELSE CONVERT(char(10), @hidate, 126)
                  END
  -- get invoice totals
  SELECT
    @storeId AS store_id,
    CASE
      WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), [DateTime], 126)
      WHEN @dimension = 'hourly' THEN REPLACE(STR(DATEPART(HOUR, [datetime]), 2), ' ', '0') + ':00:00' 
	  WHEN @dimension = 'yearly' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0')
	  WHEN @dimension = 'weekly' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0')+'-'+REPLACE(STR(DATEPART(MONTH, [datetime]), 2), ' ', '0')
      ELSE CONVERT(char(10), [DateTime], 126)
    END
    AS date_key,

    SUM(total_price) AS

    total_price,
    SUM(total_cost) AS total_cost,
    CONVERT(decimal(12, 2), 0) AS labor_cost,
    CONVERT

    (decimal(12, 2), 0) AS labor_minutes,
    '' AS datastatus INTO #invoice_totals
  FROM Invoice_Totals
  WHERE store_id = @storeId
  AND
  Status='C'
  AND

     CASE
       WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), [DateTime], 126)
       WHEN @dimension = 'hourly' THEN CONVERT(char(19), CONVERT(datetime, [DateTime], 101), 120)
	   WHEN @dimension = 'yearly' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0')
       ELSE CONVERT(char(10), [DateTime], 126)
     END
  >= @lodatevar

  AND
     CASE
       WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), [DateTime], 126)
       WHEN @dimension = 'hourly' THEN CONVERT(char(19), CONVERT(datetime, [DateTime], 101), 120)
	   WHEN @dimension = 'yearly' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0')
       ELSE CONVERT(char(10), [DateTime], 126)
     END <= @hidatevar
  GROUP BY CASE
    WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), [DateTime], 126)
    WHEN @dimension = 'hourly' THEN REPLACE(STR(DATEPART(HOUR, [datetime]), 2), ' ', '0') + ':00:00'
	WHEN @dimension = 'yearly' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0')
	WHEN @dimension = 'weekly' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0')+'-'+REPLACE(STR(DATEPART(MONTH, [datetime]), 2), ' ', '0')
    ELSE CONVERT(char(10), [DateTime], 126)
  END



  -- add in labor totals
  SELECT
    CASE
      WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), [StartDateTime], 126)
      WHEN @dimension = 'hourly' THEN REPLACE(STR(DATEPART(HOUR, [startdatetime]), 2), ' ', '0') + ':00:00'
	  WHEN @dimension = 'yearly'  THEN  REPLACE(STR(DATEPART(YEAR, [startdatetime]), 4), ' ', '0')
	  WHEN @dimension = 'weekly' THEN  REPLACE(STR(DATEPART(YEAR, [StartDateTime]), 4), ' ', '0')+'-'+REPLACE(STR(DATEPART(MONTH, [STARTdatetime]), 2), ' ', '0')
      ELSE CONVERT(char(10), [StartDateTime], 126)
    END
    AS date_key,
    SUM(isnull(numMinutes,0)) AS NumMinutes,

    SUM(isnull(wages,0)) AS Wages INTO #time_clock
  FROM Time_Clock
  WHERE store_id = @storeId
    AND

     CASE
       WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), [StartDateTime], 126)
       WHEN @dimension = 'hourly' THEN CONVERT(char(19), CONVERT(datetime, [StartDateTime], 101), 120)
	   WHEN @dimension = 'yearly' THEN  REPLACE(STR(DATEPART(YEAR, [StartDateTime]), 4), ' ', '0')
       ELSE CONVERT(char(10), [StartDateTime], 126)
     END
  >= @lodatevar

  AND
     CASE
       WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), [StartDateTime], 126)
       WHEN @dimension = 'hourly' THEN CONVERT(char(19), CONVERT(datetime, [StartDateTime], 101), 120)
	   WHEN @dimension = 'yearly' THEN  REPLACE(STR(DATEPART(YEAR, [StartDateTime]), 4), ' ', '0')
       ELSE CONVERT(char(10), [StartDateTime], 126)
     END <= @hidatevar
  GROUP BY CASE
    WHEN @dimension = 'monthly' THEN CONVERT(varchar(7), [StartDateTime], 126)
    WHEN @dimension = 'hourly' THEN REPLACE(STR(DATEPART(HOUR, [startdatetime]), 2), ' ', '0') + ':00:00'
	WHEN @dimension = 'yearly'  THEN  REPLACE(STR(DATEPART(YEAR, [startdatetime]), 4), ' ', '0')
	WHEN @dimension = 'weekly' THEN  REPLACE(STR(DATEPART(YEAR, [Startdatetime]), 4), ' ', '0')+'-'+REPLACE(STR(DATEPART(MONTH, [Startdatetime]), 2), ' ', '0')
    ELSE CONVERT(char(10), [StartDateTime], 126)
  END
  ORDER BY date_key


  UPDATE #invoice_totals
  SET labor_cost = t.Wages,


      labor_minutes = t.NumMinutes
  FROM #invoice_totals i, #time_clock t
  WHERE i.date_key =

  t.date_key

    SELECT    *
  FROM #invoice_totals
  ORDER BY date_key 
  

  SET NOCOUNT OFF
GO
/****** Object:  StoredProcedure [dbo].[get_hourlysales_comparison]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
Create Procedure [dbo].[get_hourlysales_comparison]

@storeid varchar(10),
@lodate nvarchar(20),
@hidate nvarchar(20)

as
set nocount on

declare @temptable1 as table
(
 store_id nvarchar(48),
 date_key nvarchar(36),
 total_price decimal(10,2),
  total_cost decimal(10,2),
 labor_cost decimal(10,2),
 labor_minutes  decimal(10,2),
 datastatus nvarchar(10) 
 
)

declare @temptable2 as table
( 
store_id nvarchar(48),
date_key nvarchar(36),
total_price decimal(10,2),
total_cost decimal(10,2),
labor_cost decimal(10,2),
labor_minutes decimal(10,2),
datastatus nvarchar(10)
)
Declare @hiprevdata nvarchar(20)
set @hiprevdata = @hidate + ' 00:00:00.00' 
Declare @hiprevdata1 nvarchar(20)
set @hiprevdata1 = @hidate +  ' 23:59:59.99'



Declare @loprevdata nvarchar(20)
set @loprevdata = @lodate + ' 00:00:00.00' 
Declare @loprevdata1 nvarchar(20)
set @loprevdata1 = @lodate +  ' 23:59:59.99'
Insert into @temptable1
EXEC [dbo].get_daterange_totalsales @storeid, @hiprevdata, @hiprevdata1


Insert into @temptable2
Exec [dbo].get_daterange_totalsales  @storeid,  @loprevdata, @loprevdata1

update @temptable1 set datastatus='current'

update @temptable2 set datastatus='prev'



Select * from @temptable2
UNION
Select * from @temptable1
Order by date_key


set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_itemsales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[get_itemsales]
    @storeId varchar(10),
	@lodate varchar(20),
	@hidate varchar(20),
	@dimension nvarchar(7),
	@category nvarchar(7)
as
	set nocount on

	DECLARE @lodatevar nvarchar(30)
    DECLARE @hidatevar nvarchar(30)
	
If @dimension ='Week' 
Begin
Declare @weekday as int
Declare @dim_type as nvarchar(20)

select  @weekday= WorkWeekStartDay  from setup where Store_ID = @storeId 

Declare @differ as int, @differ2 as int
select @differ =(DATEPART (weekday,@hidate)) 
set @differ2 = (@weekday+1)-@differ

set @hidate =
case 
when @differ2 > 0 then DATEADD(DAY,(7 - (@weekday+1) + @differ)*-1,@hidate)
when @differ2 < 0 then DATEADD(DAY,(@differ - (@weekday+1) )*-1,@hidate)
else @hidate
end 

Declare @hiprevdate datetime
set @hiprevdate =DATEADD(DAY,6,@hidate)

End

  SET @lodatevar =
                  CASE
                    WHEN @dimension = 'Month' THEN CONVERT(varchar(7), @hidate, 126)
                    WHEN @dimension = 'Year' THEN  REPLACE(STR(DATEPART(YEAR, @hidate), 4), ' ', '0')
					WHEN @dimension = 'Week' THEN  CONVERT(char(10), Cast(@hidate as datetime) , 126) 
					ELSE CONVERT(char(10), @hidate, 126)
                  END

  SET @hidatevar =
                  CASE
                    WHEN @dimension = 'Month' THEN CONVERT(varchar(7), @hidate, 126)
                    WHEN @dimension = 'Year' THEN  REPLACE(STR(DATEPART(YEAR, @hidate), 4), ' ', '0')
					WHEN @dimension = 'Week' THEN  CONVERT(char(10), DATEADD(DAY,6,Cast(@hidate as datetime)), 126)   
					ELSE CONVERT(char(10), @hidate, 126)
                  END

	-- get invoice totals
	select 
		@storeId as store_id,
		Inventory.Itemnum as itemNum, 
		Inventory.ItemName as item_description, 
 Round(SUM(Invoice_Itemized.Quantity),2) AS total_quantity ,
 CONVERT(char(10), Cast(@hidate as datetime) , 126) as date_key,
 SUM(Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold+Invoice_Itemized.Liability)) * (1 - Invoice_Totals.Discount) AS total_price 
	 into #Item_Totals			
	  FROM Invoice_Totals INNER JOIN ((Departments INNER JOIN Inventory 
	  ON (Departments.Store_ID = Inventory.Store_ID) AND (Departments.Dept_ID = Inventory.Dept_ID)) 
 INNER JOIN Invoice_Itemized ON (Inventory.Store_ID = Invoice_Itemized.Store_ID) AND (Inventory.ItemNum = Invoice_Itemized.ItemNum)) 
 ON (Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID) AND (Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number) 
	 where Invoice_Totals.store_id = @storeId AND Inventory.Store_ID = @storeId 
			and 
			CASE
         WHEN @dimension = 'Month' THEN CONVERT(varchar(7), [DateTime], 126)
		 WHEN @dimension = 'Year' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0') 
		  ELSE CONVERT(char(10), [DateTime], 126)
     END
  >= @lodatevar			
			and
			CASE
         WHEN @dimension = 'Month' THEN CONVERT(varchar(7), [DateTime], 126) 
		 WHEN @dimension = 'Year' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0')
		  ELSE CONVERT(char(10), [DateTime], 126)
     END
		<= @hidatevar

			AND Invoice_Totals.Status = 'C' AND Invoice_Itemized.ItemNum <> 'GIFT_C'

	 GROUP BY inventory.ItemNum ,Inventory.ItemName,Invoice_Totals.Discount 
	
	Declare @sql nvarchar(750)

	 
   Set @sql= CASE  WHEN @category = 'Units' THEN 
	 'select * from #Item_Totals	 order by total_quantity desc'
	 else
	 	'select * from #Item_Totals	 order by total_price desc'
	 end
	 	
	exec (@Sql)	

	

	set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_monthly_comparison]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
Create Procedure [dbo].[get_monthly_comparison]

@storeid varchar(10),
@lodate nvarchar(20),
@hidate nvarchar(20)

as
set nocount on

declare @temptable1 as table
(
 store_id nvarchar(48),
 date_key nvarchar(36),
 total_price decimal(10,2),
  total_cost decimal(10,2),
 labor_cost decimal(10,2),
 labor_minutes  decimal(10,2),
 datastatus  nvarchar(10)
 
)

declare @temptable2 as table
( 
store_id nvarchar(48),
date_key nvarchar(36),
total_price decimal(10,2),
total_cost decimal(10,2),
labor_cost decimal(10,2),
labor_minutes decimal(10,2),
datastatus  nvarchar(10)
)
Declare @lodatevar Nvarchar(20)
Declare @hidatevar Nvarchar(20)
set @lodatevar =@lodate
set @hidatevar = @hidate
set @lodate= @lodate + '-01'
set @lodatevar = @lodatevar + '-12'
set @hidate= @hidate + '-01'
set @hidatevar = @hidatevar + '-12'

Insert into @temptable1
EXEC [dbo].get_daterange_totalsales @storeid, @lodate, @lodatevar

Insert into @temptable2
Exec [dbo].get_daterange_totalsales  @storeid,  @hidate, @hidatevar

update @temptable2 set datastatus='current'

update @temptable1 set datastatus='prev'



Select * from @temptable2
UNION
Select * from @temptable1


set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_monthly_sales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[get_monthly_sales]
    @storeId varchar(10),
	@lodate varchar(7),
	@hidate varchar(7)
as
	set nocount on

	-- get invoice totals
	select 
		@storeId as store_id,
		convert(varchar(4),DatePart(year,[datetime])) + '-' 
			+ REPLACE(STR(DATEPART(MONTH,[datetime]),2),' ','0') 
			as date_key,
		sum(total_price)as total_price,
		sum(total_cost) as total_cost,
		convert(decimal(12,2),0) as labor_cost,
		convert(decimal(12,2),0) as labor_minutes,
		'' as datastatus
	 into #invoice_totals			
	 from Invoice_Totals 
	 where store_id = @storeId
			and 
			(convert(varchar(4),DatePart(year,[datetime])) + '-' 
				+ REPLACE(STR(DATEPART(MONTH,[datetime]),2),' ','0') >= @lodate)
			and
			(convert(varchar(4),DatePart(year,[datetime])) + '-' 
				+ REPLACE(STR(DATEPART(MONTH,[datetime]),2),' ','0') <= @hidate)
		group by DatePart(year,[datetime]), DATEPART(month,[datetime])

	-- add in labor totals
	select
			convert(varchar(4),DatePart(year,[StartDateTime])) + '-' 
			+ REPLACE(STR(DATEPART(MONTH,[StartDateTime]),2),' ','0') 
			as date_key,
			'' as datastatus,
			sum(numMinutes) as NumMinutes,
			sum(wages) as Wages
	into #time_clock
	from Time_Clock	
	group by DatePart(year,[StartDateTime]), DATEPART(month,[StartDateTime])

	
	update #invoice_totals
		set labor_cost = t.Wages,
			labor_minutes = t.NumMinutes
		from #invoice_totals i, #time_clock t
		where i.date_key = t.date_key

	select * from #invoice_totals order by date_key

	set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_monthlydepartment_sales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[get_monthlydepartment_sales]
    @storeId varchar(10),
	@lodate varchar(20),
	@hidate varchar(20),
	@dimension nvarchar(7),
	@category nvarchar(7)
as
	set nocount on

	DECLARE @lodatevar nvarchar(30)
    DECLARE @hidatevar nvarchar(30)



If @dimension ='Week' 
Begin
Declare @weekday as int
Declare @dim_type as nvarchar(20)

select  @weekday= WorkWeekStartDay  from setup where Store_ID = @storeId 


Declare @differ as int, @differ2 as int
select @differ =(DATEPART (weekday,@hidate)) 
set @differ2 = (@weekday+1)-@differ

set @hidate =
case 
when @differ2 > 0 then DATEADD(DAY,(7 - (@weekday+1) + @differ)*-1,@hidate)
when @differ2 < 0 then DATEADD(DAY,(@differ - (@weekday+1) )*-1,@hidate)
else @hidate
end 

Declare @hiprevdate datetime
set @hiprevdate =DATEADD(DAY,6,@hidate)

End

  SET @lodatevar =
                  CASE
                    WHEN @dimension = 'Month' THEN CONVERT(varchar(7), @hidate, 126)
                    WHEN @dimension = 'Year' THEN  REPLACE(STR(DATEPART(YEAR, @hidate), 4), ' ', '0')
					WHEN @dimension = 'Week' THEN  CONVERT(char(10), Cast(@hidate as datetime) , 126) 
					ELSE CONVERT(char(10), @hidate, 126)
                  END

  SET @hidatevar =
                  CASE
                    WHEN @dimension = 'Month' THEN CONVERT(varchar(7), @hidate, 126)
                    WHEN @dimension = 'Year' THEN  REPLACE(STR(DATEPART(YEAR, @hidate), 4), ' ', '0')
					WHEN @dimension = 'Week' THEN  CONVERT(char(10), DATEADD(DAY,6,Cast(@hidate as datetime)), 126)   
					ELSE CONVERT(char(10), @hidate, 126)
                  END
	-- get invoice totals
	select 
		@storeId as store_id,
		 Departments.Dept_ID as dept_id,
		 		  
		Departments.Description as dept_description, 
		
 SUM((Invoice_Itemized.Quantity * (Invoice_Itemized.PricePer+Invoice_Itemized.GC_Sold+Invoice_Itemized.Liability)) * (1 - Invoice_Totals.Discount) )AS total_price,
  Round(SUM(Invoice_Itemized.Quantity),2) AS total_quantity, CONVERT(char(10), Cast(@hidate as datetime) , 126) as date_key
	 into #Department_Totals			
	  FROM Invoice_Totals INNER JOIN ((Departments INNER JOIN Inventory 
	  ON (Departments.Store_ID = Inventory.Store_ID) AND (Departments.Dept_ID = Inventory.Dept_ID)) 
 INNER JOIN Invoice_Itemized ON (Inventory.Store_ID = Invoice_Itemized.Store_ID) AND (Inventory.ItemNum = Invoice_Itemized.ItemNum)) 
 ON (Invoice_Totals.Store_ID = Invoice_Itemized.Store_ID) AND (Invoice_Totals.Invoice_Number = Invoice_Itemized.Invoice_Number) 
	 where Invoice_Totals.store_id = @storeId AND Inventory.Store_ID = @storeId 
			and
			CASE
         WHEN @dimension = 'Month' THEN CONVERT(varchar(7), [DateTime], 126)
		 WHEN @dimension = 'Year' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0') 
		  ELSE CONVERT(char(10), [DateTime], 126)
     END
  >= @lodatevar			
			and
			CASE
         WHEN @dimension = 'Month' THEN CONVERT(varchar(7), [DateTime], 126) 
		 WHEN @dimension = 'Year' THEN  REPLACE(STR(DATEPART(YEAR, [datetime]), 4), ' ', '0')
		  ELSE CONVERT(char(10), [DateTime], 126)
     END
		<= @hidatevar


			AND Invoice_Totals.Status = 'C' AND Invoice_Itemized.ItemNum <> 'GIFT_C'

	 GROUP BY Departments.Dept_ID, Departments.Description

	 Declare @sql nvarchar(750)

	 
   Set @sql= CASE  WHEN @category = 'Units' THEN 
	 'select * from #Department_Totals order by total_quantity desc'
	 else
	 	'select * from #Department_Totals order by total_price desc'
	 end
	 	
	exec (@Sql)	
	
	
	set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_weekly_sales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[get_weekly_sales]
   @storeid varchar(10),
@lodate datetime,
@hidate datetime
as
set nocount on

declare @temptable1 as table
(
 store_id nvarchar(48),
 date_key nvarchar(36),
 total_price decimal(12,2),
 total_cost decimal(12,2),
 labor_cost decimal(12,2),
 labor_minutes  decimal(12,2),
 datastatus nvarchar(10) 
 
)

declare @temptable2 as table
(
 store_id nvarchar(48),
 date_key nvarchar(36),
 total_price decimal(12,2),
 total_cost decimal(12,2),
 labor_cost decimal(12,2),
 labor_minutes  decimal(12,2),
 datastatus nvarchar(10) 
 
)

Declare @weekday as int
select  @weekday= WorkWeekStartDay  from setup  where Store_ID = @storeId 

Declare @differ as int, @differ2 as int
select @differ =(DATEPART (weekday,@hidate)) 
set @differ2 = (@weekday+1)-@differ

set @hidate =
case 
when @differ2 > 0 then DATEADD(DAY,(7 - (@weekday+1) + @differ)*-1,@hidate)
when @differ2 < 0 then DATEADD(DAY,(@differ - (@weekday+1) )*-1,@hidate)
else @hidate
end 
Declare @hiprevdate datetime
set @hiprevdate =DATEADD(DAY,6,@hidate)





Declare @temphidate nvarchar(20)
Declare @temphiprevdate nvarchar(20)
set @temphidate = CONVERT(char(10), @hidate,126)
set @temphiprevdate = CONVERT(char(10), @hiprevdate, 126)
 

Insert into @temptable1 
EXEC get_daterange_totalsales @storeid,   @temphidate,@temphiprevdate,'weekly'
If Exists(select * from @temptable1) 
Begin
update @temptable1 set date_key = CONVERT(char(10), @hidate,126)
End
Else
Begin
Insert into @temptable1 values(@storeid , CONVERT(char(10), @hidate,126),0,0,0,0,'')
End
Insert into @temptable2 select store_id,date_key ,Sum(total_price) ,sum( total_cost) ,sum( labor_cost) ,sum(labor_minutes),datastatus from @temptable1
group by store_id,date_key,datastatus
 
select * from @temptable2

set nocount off
GO
/****** Object:  StoredProcedure [dbo].[get_weeklysales_comparison]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
Create Procedure [dbo].[get_weeklysales_comparison]

@storeid varchar(10),
@lodate datetime,
@hidate datetime

as
set nocount on

declare @temptable1 as table
(
 store_id nvarchar(48),
 date_key nvarchar(36),
 total_price decimal(10,2),
  total_cost decimal(10,2),
 labor_cost decimal(10,2),
 labor_minutes  decimal(10,2),
 datastatus nvarchar(10) 
 
)

declare @temptable2 as table
( 
store_id nvarchar(48),
date_key nvarchar(36),
total_price decimal(10,2),
total_cost decimal(10,2),
labor_cost decimal(10,2),
labor_minutes decimal(10,2),
datastatus nvarchar(10)

)
Declare @hiprevdate DateTime
set @hiprevdate =DATEADD(DAY,6,@hidate)

Declare @temphidate nvarchar(20)
Declare @temphiprevdate nvarchar(20)
set @temphidate = CONVERT(char(10), @hidate,126)
set @temphiprevdate = CONVERT(char(10), @hiprevdate,126)



Insert into @temptable1
EXEC [dbo].get_daterange_totalsales @storeid,  @temphidate ,@temphiprevdate


Declare @loprevdate DateTime
set @loprevdate =DATEADD(DAY,6,@lodate)


Declare @templodate nvarchar(20)
Declare @temploprevdate nvarchar(20)
set @templodate = CONVERT(char(10), @lodate,126)
set @temploprevdate = CONVERT(char(10), @loprevdate,126)


Insert into @temptable2
Exec [dbo].get_daterange_totalsales  @storeid,  @templodate , @temploprevdate

update @temptable1 set datastatus='current'

update @temptable2 set datastatus='prev'


Select * from @temptable2
UNION
Select * from @temptable1


set nocount off
GO
/****** Object:  StoredProcedure [dbo].[labor_timeclock_calc]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
 -- Employee_AdditionalInfo
create procedure [dbo].[labor_timeclock_calc]
    @storeId varchar(10),
	@startDateTime varchar(25),
	@endDateTime varchar(25)
as
	set nocount on

	-- version: 2.0
	declare @SixtyInDecimal decimal(12,2)
	declare @workweekStartDay int
	declare @overtimeCalculationMethod int
	declare @endDateTimeToUseForCalc datetime 

	select @SixtyInDecimal = convert(decimal(12,2),60)

	--- we want to use the machine time to calculate open timecards
	select @endDateTimeToUseForCalc = convert(DateTime,@endDateTime)

	--select @endDateTimeToUseForCalc = Convert(datetime,'10/9/2017 7:00:00 PM') --@@TEST
	-- select @endDateTimeToUseForCalc = Convert(datetime,'9/22/2017 1:52:00 PM')



	-- 0 sunday, 1 monday, etc, from CRE, SQL starts at 1
	select @workweekStartDay = (select workweekstartday from setup where store_Id = @storeId)

	-- make the adjustment here, as were working in SQL (SQL starts at 1)
	select @workweekStartDay = @workweekStartDay + 1

	-- 0 is weekly, 1 is daily
	select @overtimeCalculationMethod = (select IsNull(OvertimeCalculationMethod,0) from setup where store_Id = @storeId)

	-- calculate start time
	Set @startDateTime =  isnull((select min(StartDateTime) 
		from Time_Clock  
		where (EndDateTime is  null or EndDateTime = '' or EndDateTime between  @startDateTime and  @endDateTime )),@startDateTime)

	-- create temporary working table
	select 	case when endDateTime IS NULL THEN '1' ELSE '0' END as IsStillLoggedIn,
		convert(bit,0) as isOutOfRange, -- requires out of range records to calculate overtime, were not going to output these
		convert(int,0) as periodNo,
		convert(int,0) as OrigTotalMinutes,
		Convert(int,0) as NumMinutesBreak,
		convert(Decimal(12,2),isnull(NumMinutes,0)) as NumMinutes,
		convert(Decimal(12,2),isnull(NumMinutes,0) ) as TotalMinutes,		
		convert(Decimal(12,2), isnull((round(wages/hourly_wage,0) * 60),0) ) as RegularMinutes,
		convert(Decimal(12,2), 0) as OvertimeMinutes,
		convert(Decimal(12,2), 0) as OvertimeMinutesAtTimeAndAHalf,
		convert(Decimal(12,2), 0) as OvertimeMinutesAtDoubleTime,
		convert(Decimal(12,2), 0) as TotalHours,
		convert(Decimal(12,2), 0) as RegularHours,
		CONVERT(DECIMAL(12,2), 0) as overtimeHours,
		convert(Decimal(12,2), 0) as wages, 		
		convert(Decimal(12,2), 0) as OvertimeWagesAtTimeAndAHalf,		
		convert(Decimal(12,2), 0) as OvertimeWagesAtDoubleTime,				
		convert(Decimal(12,2),hourly_wage) as 'hourly_wage' , convert(Decimal(12,2), taxes) as 'taxes', convert(Decimal(12,2), tips) as 'tips', 
		convert(Decimal(12,2), OverTimeHourly_Wage) as 'OverTimeHourly_Wage' ,convert(Decimal(12,2), 0) as  OvertimeWagesEarned,
		convert(int,0) as DaysInARow,
		convert(Decimal(12,2), 0) as NumMinutesBreakPaid, convert(Decimal(12,2), 0) as NumMinutesBreakUnpaid, [status],
		store_id, cashier_id, Id, JobCodeId, 
		startDateTime, 
		case when endDateTime IS NULL THEN @endDateTimeToUseForCalc ELSE endDateTime END as endDateTime,
		convert(Decimal(12,2), 0) as Total_Cash_Sales, convert(Decimal(12,2), 0) as Cash_Tips_Taken,
		convert(varchar(20),'') as payroll_employee_number,
		convert(varchar(60),'') as payname,
		-- a few to handle the mapping formatting in heartbear
		convert(varchar(10),'') as startDate,
		convert(varchar(10),'') as startTime,
		convert(varchar(10),'') as endTime,
		convert(varchar(10),'') as dateIn,
		convert(varchar(10),'') as dateOut,
		convert(decimal(12,2),0) as doubleTimeRate,
		convert(varchar(10),'') as overtimeStarts,
		convert(varchar(20),'') as jobcode_desc,
		convert(varchar(20),'') as transactionId,
		ClockOutStation_ID

		into #timeclockRaw
        from time_clock
        where  
			store_id = @storeId and StartDateTime >= @startDateTime 
				and case when endDateTime IS NULL THEN @endDateTimeToUseForCalc ELSE endDateTime END <= @endDateTime
				order by cashier_Id, startDateTime, jobcodeId
		
		-- figure out the start of pay period, so we can group the time clock later
		declare @startDateForPayPeriod DateTime ;	
		declare @dtTemp datetime
		select @dtTemp = (select min(startDateTime) from #timeclockRaw)								
		select @startDateForPayPeriod = [dbo].getStartDateOfPayPeriod(@dtTemp, @workweekStartDay) -- -> is the startDate of payperiod = 0
		-------------------------------------------------------------------------

		-- we need to get all of the records into #timeclock so we can calc overtime
		insert into #timeclockRaw (id, store_id, cashier_id, isOutOfRange, IsStillLoggedIn, StartDateTime, EndDateTime,[status],
				JobCodeID, ClockOutStation_ID, hourly_wage, OverTimeHourly_Wage, NumMinutesBreak,
				OvertimeMinutesAtTimeAndAHalf, OvertimeMinutesAtDoubleTime,
				DaysInARow, NumMinutesBreakPaid, NumMinutesBreakUnpaid,
				Total_Cash_Sales, Cash_Tips_Taken
				)		
			select 
				id,
				store_id,
				cashier_id,
				1 as isOutOfRange, 
				case when endDateTime IS NULL THEN '1' ELSE '0' END as IsStillLoggedIn,
				StartDateTime,
				case when endDateTime IS NULL THEN @endDateTimeToUseForCalc ELSE endDateTime END as endDateTime,
				[status],
				JobCodeID,
				ClockOutStation_ID,
				Hourly_Wage,
				OvertimeHourly_Wage,
				0 as NumMinutesBreak,
				0 as OvertimeMinutesAtTimeAndAHalf,
				0 as OvertimeMinutesAtDoubleTime,
				0 as DaysInARow,
				0 as NumMinutesBreakPaid,
				0 as NumMinutesBreakUnpaid,
				0 as Total_Cash_Sales,
				0 as Cash_Tips_Taken
			from Time_Clock
			where 			        
				store_id = @storeId and StartDateTime >= @startDateForPayPeriod 
				and StartDateTime < @startDateTime -- it's less than start date time because we will already have that
	
		-- for the calcs they have to be in order, so we take the two inserts and sort them together
		-- into the #timeclock
		select * into #timeclock
			from #timeclockRaw
			order by cashier_Id, startDateTime, jobcodeId
				
		update #timeclock set payname = 
				isnull(emp.first_Name + ' ' +  emp.Last_Name,'undefined, ' + tc.Cashier_ID)
				from employee emp, #timeclock tc
				where emp.cashier_id = tc.cashier_id


		--- get the employee payroll number (even if we may not need it yet)
		update #timeclock set payroll_employee_number = emp.payroll_employee_number
				from Employee_AdditionalInfo emp, #timeclock tc
				where emp.cashier_id = tc.cashier_id

		--- set up the temporary #timeclockbreaks
		--- it's a one to many from the #timeclock to the timeclock breaks
		select 
			case when b.BreakEndDateTime IS NULL THEN '1' ELSE '0' END as IsBreakOpen,
			convert(varchar(10),'') as dateIn,
			convert(varchar(10),'') as startTime,
			convert(varchar(10),'') as endTime,
			convert(varchar(10),'') as dateOut,
			convert(varchar(20),'') as cashierId,
			convert(varchar(20),'') as payname,
			convert(varchar(20),'') as JobCodeId,
			convert(varchar(20),'') as jobcode_desc,
			convert(varchar(20),'') as transactionId,
			convert(varchar(20),'') as clockoutstation_id,
			case when b.paid = 1 THEN 'true' ELSE 'false' END as isPaidBreak,
			case when b.paid = 0 THEN 'true' ELSE 'false' END as isUnPaidBreak,
			b.* into #timeclockbreaks
			from Time_Clock_Breaks b, #timeclock t
			where b.ID = t.ID

		update #timeclockbreaks
			set BreakEndDateTime =  @endDateTimeToUseForCalc
			where BreakEndDateTime is null

		update #timeclockbreaks					
			set NumMinutesBreak = DATEDIFF(mi, BreakStartDateTime, BreakEndDateTime)			
			where IsBreakOpen = 1 and Paid = 0

		update #timeclockbreaks					
			set dateIn =  CONVERT(VARCHAR(10), BreakStartDateTime, 101) ,
				dateOut = CONVERT(VARCHAR(10), BreakEndDateTime, 101),
				startTime =  CONVERT(VARCHAR(5), BreakStartDateTime, 8),
				endTime = CONVERT(VARCHAR(5), BreakEndDateTime, 8)


		--- if the break is open, then we have to ADD the NumMinutesBreak for OPEN breaks
		--- it's assumed that there is ONLY 1 open break
		update #timeclock					
			set NumMinutesBreak = t.NumMinutesBreak + DATEDIFF(mi, BreakStartDateTime, BreakEndDateTime)
			from #timeclock t, #timeclockbreaks b
			where t.id = b.Id
				and b.Paid = 0
				and b.IsBreakOpen = 1

		-- updates for logged in employees -----------------------------		
		
		--- calculate the minutes, using the incoming enddate time (now)
		update #timeclock
			set TotalMinutes = DATEDIFF(mi, StartDateTime, endDateTime),
				NumMinutes = DATEDIFF(mi, StartDateTime, endDateTime)
			where IsStillLoggedIn = 1


		--- get the jobcode name 
		update #timeclock
			set jobcode_desc = JobCode.JobCodeName
			from #timeclock, JobCode
			where #timeclock.JobCodeID = jobCode.JobCodeID
			

		--- update for breaks, note it's a sum on the timeclockbreaks as there may be one than one break				
		update #timeclock
			set NumMinutesBreak = tb.numMinutesBreak 
			from #timeClock tc, (select id, sum(NumMinutesBreak) as numMinutesBreak 
								from #timeclockbreaks
								where Paid = 0
								group by id
								) tb
			where tc.id = tb.ID

		update #timeclock
			set OrigTotalMinutes = DATEDIFF(mi, StartDateTime, EndDateTime)

		update #timeclock
			set TotalMinutes = Case when ( (OrigTotalMinutes - NumMinutesBreak) > 0) then OrigTotalMinutes - NumMinutesBreak else 0 end ,
			NumMinutes =  Case when ( (OrigTotalMinutes - NumMinutesBreak) > 0) then OrigTotalMinutes - NumMinutesBreak else 0 end 
				
	
		-- update for everybody, now that we have num minutes
		update #timeclock
			set TotalHours = Convert(Decimal(8,2), TotalMinutes/convert(decimal(5,2),60))
				
		-- specific record vars
		declare @cCashierId varchar(20)
		declare @cIsStillLoggedIn int
		Declare @cTotalMinutes Decimal(8,2)
		Declare @cPeriodNo int
		Declare @cId int
		declare @cStartDateTime DateTime

		declare @minutesForPeriod Decimal(8,2)
		-- 
		declare @fortyHoursInMinutes Decimal(8,2)
		select @fortyHoursInMinutes = 2400 ;

		declare @lastPeriodBreak varchar(30)
		select @lastPeriodBreak = '~'

		declare @lastSequentialDaysBreak varchar(30)
		select @lastSequentialDaysBreak = '~'
		declare @currentDaysBreak varchar(30)

		-- weekly method of overtime calculation -----------------------------
		if @overtimeCalculationMethod = 0 begin 
			
			update #timeclock set periodNo = convert(int,DateDiff(d, @startDateForPayPeriod, startDateTime) / 7)

			DECLARE db_cursor CURSOR FOR  
			SELECT cashier_id, IsStillLoggedIn, TotalMinutes, PeriodNo, Id
				FROM #timeclock 			
				order by cashier_id, periodNo, StartDateTime

			OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId
		
			WHILE @@FETCH_STATUS = 0   
			BEGIN   					
					declare @regTimeBucket Decimal(8,2)
					declare @otTimeBucket Decimal(8,2)
					declare @amtToAllocate2 Decimal(8,2)
					declare @minutesNeededToGetTo40 Decimal(8,2)

					select @amtToAllocate2 = @cTotalMinutes
					select @regTimeBucket = 0
					select @otTimeBucket = 0
					
					if( @lastPeriodBreak <> @cCashierId + convert(varchar(10),@cPeriodNo)) begin
						select @lastPeriodBreak = @cCashierId + convert(varchar(10),@cPeriodNo)					
						select @minutesForPeriod = 0
					end					
				
					--- if it all falls into overtime, before we add the accumulator
					if (@minutesForPeriod >= @fortyHoursInMinutes) begin
						-- were over the forty hour mark, prior to this entry, so it's all overtime
						select @otTimeBucket = @cTotalMinutes						
					end else begin
						-- how many minutes to we need to get it to 40
						select @minutesNeededToGetTo40 = case when (@fortyHoursInMinutes - @minutesForPeriod > 0) then @fortyHoursInMinutes - @minutesForPeriod else 0 end
						if @minutesNeededToGetTo40 > @amtToAllocate2 begin
							select @regTimeBucket = @amtToAllocate2
						end else begin
							select @regTimeBucket = case when @cTotalMinutes - @minutesNeededToGetTo40 > 0 then @minutesNeededToGetTo40 else  @cTotalMinutes end
							select @otTimeBucket = @cTotalMinutes - @regTimeBucket
						end 
					end
			
					update #timeclock set RegularMinutes = @regTimeBucket, OvertimeMinutes = @otTimeBucket
						where id = @cId
			
					select @minutesForPeriod = @minutesForPeriod + @cTotalMinutes				
			
					FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId			
			END   

			CLOSE db_cursor   
			DEALLOCATE db_cursor
						
			update #timeclock set wages = (RegularMinutes / 60) * Hourly_Wage,
					OvertimeWagesEarned = (OvertimeMinutes / 60) * OverTimeHourly_Wage,
					overtimeHours = OvertimeMinutes/@SixtyInDecimal					
		end 
		-- end of weekly overtime calculation
		
		-- daily method of overtime calculation -----------------------------
		if @overtimeCalculationMethod = 1 begin 			
			update #timeclock set periodNo = DATEPART(DAYOFYEAR, StartDateTime)
			
			-- under 8 hours is standard rate
			-- 8 - 12 is 1.5 standard rate
			declare @8HourThresholdInMinutes Decimal(8,2)
			select @8HourThresholdInMinutes = 480

			-- 12 and over is double time
			declare @12HourThresholdInMinutes Decimal(8,2)
			select @12HourThresholdInMinutes = 720

			declare @otTimeAndAHalf Decimal(8,2)
			declare @otDoubleTime Decimal(8,2)

			declare @workedDaysInARow int
			declare @workedDaysInARowDate DateTime 

			DECLARE db_cursor CURSOR FOR  
			SELECT cashier_id, IsStillLoggedIn, TotalMinutes, PeriodNo, Id, StartDateTime
				FROM #timeclock 			
				order by cashier_id, periodNo, StartDateTime

			OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId, @cStartDateTime
		
			WHILE @@FETCH_STATUS = 0   
			BEGIN   
					--- update for current record
					select @otTimeAndAHalf = 0
					select @otDoubleTime = 0
					select @regTimeBucket = 0
					
					--- temp vars
					declare @minutesNeededToGetTo8 Decimal(8,2)
					declare @minutesNeededToGetTo12 Decimal(8,2)

					--- this is for a period break (per day, in daily)
					if( @lastPeriodBreak <> @cCashierId + convert(varchar(10),@cPeriodNo)) begin
						select @lastPeriodBreak = @cCashierId + convert(varchar(10),@cPeriodNo)					
						select @minutesForPeriod = 0						
					end
					
					--- set up for 7th day worked in a row
					declare @payPeriod int
					declare @breakDateFor7thDate datetime 
					declare @currentDateFor7thDate datetime 
					select @payPeriod = convert(int,DateDiff(d, @startDateForPayPeriod, @cStartDateTime) / 7)					

					select @currentDaysBreak = @ccashierId + '.' + Convert(varchar(4), @payPeriod)					
					if @lastSequentialDaysBreak <> @currentDaysBreak begin					
						select @lastSequentialDaysBreak = @currentDaysBreak						
						select @workedDaysInARow = 0
						select @breakDateFor7thDate = [dbo].getStartDateOfPayPeriod(@cStartDateTime,@workweekStartDay)	
					end
					
					if DatePart(dy,@cStartDateTime) = DatePart(dy,@breakDateFor7thDate) begin
						select @workedDaysInARow = @workedDaysInARow + 1
						select @breakDateFor7thDate = DateAdd(dd,1, @breakDateFor7thDate)
					end 

					declare @diff Decimal(8,2)
					declare @amtToAllocate Decimal(8,2)					
					select @amtToAllocate = @cTotalMinutes
					
					select @minutesNeededToGetTo8 = @8HourThresholdInMinutes - @minutesForPeriod
					
					if @workedDaysInARow = 7 begin
						select @otTimeAndAHalf = case when (@amtToAllocate <= @minutesNeededToGetTo8) then  @amtToAllocate else  @minutesNeededToGetTo8 end 
						select @amtToAllocate = @amtToAllocate - @otTimeAndAHalf
						select @otDoubleTime = case when (@amtToAllocate > 0) then  @amtToAllocate else  0 end 
					end else begin
						if @minutesNeededToGetTo8 > 0 begin						
							select @regTimeBucket = case when (@minutesNeededToGetTo8 - @amtToAllocate > 0) then @amtToAllocate else  @minutesNeededToGetTo8 end 
							
							select @amtToAllocate = @amtToAllocate - @regTimeBucket   
							--select @cId, @regTimeBucket, @amtToAllocate
							--- add to summary total
							select @minutesForPeriod = @minutesForPeriod + @regTimeBucket				
						end 
					 
						--- were in the 8-12 range
						select @minutesNeededToGetTo12 = @12HourThresholdInMinutes - @minutesForPeriod
						if @minutesNeededToGetTo12 > 0 begin						
							select @otTimeAndAHalf = case when (@minutesNeededToGetTo12 - @amtToAllocate > 0) then  @amtToAllocate else  @minutesNeededToGetTo12 end 
							select @amtToAllocate = @amtToAllocate - @otTimeAndAHalf   
						
							--- add to summary total
							select @minutesForPeriod = @minutesForPeriod + @otTimeAndAHalf				
						end 

						if @amtToAllocate > 0 begin
							select @otDoubleTime = @amtToAllocate
							select @minutesForPeriod = @minutesForPeriod + @otDoubleTime
							select @amtToAllocate = 0
						end
					end
					update #timeclock set RegularMinutes = @regTimeBucket,
							OvertimeMinutesAtTimeAndAHalf = @otTimeAndAHalf,
							OvertimeMinutesAtDoubleTime = @otDoubleTime,
							DaysInARow = @workedDaysInARow
							where Id = @cId

					FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId, @cStartDateTime
			END   

			CLOSE db_cursor   
			DEALLOCATE db_cursor

			update #timeclock set wages = (RegularMinutes / 60) * Hourly_Wage,
					OvertimeWagesAtTimeAndAHalf = (OvertimeMinutesAtTimeAndAHalf / 60) * (hourly_wage * 1.5),
					OvertimeWagesAtDoubleTime = (OvertimeMinutesAtDoubleTime / 60) * hourly_wage * 2

			update #timeclock set OvertimeWagesEarned = OvertimeWagesAtTimeAndAHalf + OvertimeWagesAtDoubleTime,
					OvertimeMinutes = OvertimeMinutesAtTimeAndAHalf + OvertimeMinutesAtDoubleTime,
					overtimeHours = (OvertimeMinutesAtDoubleTime + OvertimeMinutesAtTimeAndAHalf)/@SixtyInDecimal
		end

		update #timeClock	
				set startDate = CONVERT(VARCHAR(10), StartDateTime, 101) ,
					startTime = CONVERT(VARCHAR(5), StartDateTime, 8),
					endTime =CONVERT(VARCHAR(5), EndDateTime, 8) ,
					dateIn = CONVERT(VARCHAR(10), StartDateTime, 101) ,
					dateOut = CONVERT(VARCHAR(10), EndDateTime, 101) ,
					doubleTimeRate = hourly_wage * 2,
					regularHours = RegularMinutes / @SixtyInDecimal
					

		-- add reference fields to breaks
		update #timeclockbreaks
			set cashierId = t.Cashier_ID,
				payname = t.payname,
				JobCodeId = t.JobCodeID,
				jobcode_desc = t.jobcode_desc,
				clockoutstation_id = t.ClockOutStation_ID,
				transactionId = t.id
			from #timeclockbreaks b, #timeclock t
				where b.id = t.id
		
		update #timeclock 
			set endTime = '',
				dateOut = ''				
			where IsStillLoggedIn = 1
			
		update #timeclockbreaks
			set endTime = '',
			DateOut = ''
			where IsBreakOpen = 1

		update #timeclock
			set transactionId = convert(varchar(10),Convert(int,id) + 5000000)

		update #timeclockbreaks
			set transactionId = convert(varchar(10),Convert(int,id) + 5000000)
		
		select transactionId as trxId, cashier_id as cashierId,* from #timeclock 
			where isOutOfRange = 0  -- were now bringing in records for the entire payperiod, to properly calc overtime, if it's zero it's in the range
			order by cashier_id, periodNo, StartDateTime

		select * from #timeclockbreaks 
			where id in (select id from #timeclock where isOutOfRange = 0)
			order by cashierId, transactionId
			


		--- diag

		--select 'x',id, totalminutes,OrigTotalMinutes, numMinutesBreak, NumMinutes, StartDateTime, endDateTime, isOutOfRange from #timeclock 
		--	where Cashier_ID = '100106'
		--	order by cashier_Id, startDateTime, jobcodeId
		
		--select 'z',cashier_Id, sum(totalminutes) as totalminutes , sum(overtimeMinutes) as overtimeMinutes
		--	from #timeclock
		--	group by cashier_Id

    set nocount off
GO
/****** Object:  StoredProcedure [dbo].[labor_timeclock_calc_old]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
 -- Employee_AdditionalInfo
create procedure [dbo].[labor_timeclock_calc_old]
    @storeId varchar(10),
	@startDateTime varchar(25),
	@endDateTime varchar(25)
as
	set nocount on

	-- version: 2.0
	declare @SixtyInDecimal decimal(12,2)
	declare @workweekStartDay int
	declare @overtimeCalculationMethod int
	declare @endDateTimeToUseForCalc datetime 

	select @SixtyInDecimal = convert(decimal(12,2),60)

	--- we want to use the machine time to calculate open timecards
	select @endDateTimeToUseForCalc = convert(DateTime,@endDateTime)

	--select @endDateTimeToUseForCalc = Convert(datetime,'10/9/2017 7:00:00 PM') --@@TEST
	-- select @endDateTimeToUseForCalc = Convert(datetime,'9/22/2017 1:52:00 PM')



	-- 0 sunday, 1 monday, etc, from CRE, SQL starts at 1
	select @workweekStartDay = (select workweekstartday from setup where store_Id = @storeId)

	-- make the adjustment here, as were working in SQL (SQL starts at 1)
	select @workweekStartDay = @workweekStartDay + 1

	-- 0 is weekly, 1 is daily
	select @overtimeCalculationMethod = (select IsNull(OvertimeCalculationMethod,0) from setup where store_Id = @storeId)

	-- calculate start time
	Set @startDateTime =  isnull((select min(StartDateTime) 
		from Time_Clock  
		where (EndDateTime is  null or EndDateTime = '' or EndDateTime between  @startDateTime and  @endDateTime )),@startDateTime)

	-- create temporary working table
	select 	case when endDateTime IS NULL THEN '1' ELSE '0' END as IsStillLoggedIn,
		convert(bit,0) as isOutOfRange, -- requires out of range records to calculate overtime, were not going to output these
		convert(int,0) as periodNo,
		convert(int,0) as OrigTotalMinutes,
		Convert(int,0) as NumMinutesBreak,
		convert(Decimal(12,2),isnull(NumMinutes,0)) as NumMinutes,
		convert(Decimal(12,2),isnull(NumMinutes,0) ) as TotalMinutes,		
		convert(Decimal(12,2), isnull((round(wages/hourly_wage,0) * 60),0) ) as RegularMinutes,
		convert(Decimal(12,2), 0) as OvertimeMinutes,
		convert(Decimal(12,2), 0) as OvertimeMinutesAtTimeAndAHalf,
		convert(Decimal(12,2), 0) as OvertimeMinutesAtDoubleTime,
		convert(Decimal(12,2), 0) as TotalHours,
		convert(Decimal(12,2), 0) as RegularHours,
		CONVERT(DECIMAL(12,2), 0) as overtimeHours,
		convert(Decimal(12,2), 0) as wages, 		
		convert(Decimal(12,2), 0) as OvertimeWagesAtTimeAndAHalf,		
		convert(Decimal(12,2), 0) as OvertimeWagesAtDoubleTime,				
		convert(Decimal(12,2),hourly_wage) as 'hourly_wage' , convert(Decimal(12,2), taxes) as 'taxes', convert(Decimal(12,2), tips) as 'tips', 
		convert(Decimal(12,2), OverTimeHourly_Wage) as 'OverTimeHourly_Wage' ,convert(Decimal(12,2), 0) as  OvertimeWagesEarned,
		convert(int,0) as DaysInARow,
		convert(Decimal(12,2), 0) as NumMinutesBreakPaid, convert(Decimal(12,2), 0) as NumMinutesBreakUnpaid, [status],
		store_id, cashier_id, Id, JobCodeId, 
		startDateTime, 
		case when endDateTime IS NULL THEN @endDateTimeToUseForCalc ELSE endDateTime END as endDateTime,
		convert(Decimal(12,2), 0) as Total_Cash_Sales, convert(Decimal(12,2), 0) as Cash_Tips_Taken,
		convert(varchar(20),'') as payroll_employee_number,
		convert(varchar(60),'') as payname,
		-- a few to handle the mapping formatting in heartbear
		convert(varchar(10),'') as startDate,
		convert(varchar(10),'') as startTime,
		convert(varchar(10),'') as endTime,
		convert(varchar(10),'') as dateIn,
		convert(varchar(10),'') as dateOut,
		convert(decimal(12,2),0) as doubleTimeRate,
		convert(varchar(10),'') as overtimeStarts,
		convert(varchar(20),'') as jobcode_desc,
		convert(varchar(20),'') as transactionId,
		ClockOutStation_ID

		into #timeclockRaw
        from time_clock
        where  
			store_id = @storeId and StartDateTime >= @startDateTime 
				and case when endDateTime IS NULL THEN @endDateTimeToUseForCalc ELSE endDateTime END <= @endDateTime
				order by cashier_Id, startDateTime, jobcodeId
		
		-- figure out the start of pay period, so we can group the time clock later
		declare @startDateForPayPeriod DateTime ;	
		declare @dtTemp datetime
		select @dtTemp = (select min(startDateTime) from #timeclockRaw)								
		select @startDateForPayPeriod = [dbo].getStartDateOfPayPeriod(@dtTemp, @workweekStartDay) -- -> is the startDate of payperiod = 0
		-------------------------------------------------------------------------

		-- we need to get all of the records into #timeclock so we can calc overtime
		insert into #timeclockRaw (id, store_id, cashier_id, isOutOfRange, IsStillLoggedIn, StartDateTime, EndDateTime,[status],
				JobCodeID, ClockOutStation_ID, hourly_wage, OverTimeHourly_Wage, NumMinutesBreak,
				OvertimeMinutesAtTimeAndAHalf, OvertimeMinutesAtDoubleTime,
				DaysInARow, NumMinutesBreakPaid, NumMinutesBreakUnpaid,
				Total_Cash_Sales, Cash_Tips_Taken
				)		
			select 
				id,
				store_id,
				cashier_id,
				1 as isOutOfRange, 
				case when endDateTime IS NULL THEN '1' ELSE '0' END as IsStillLoggedIn,
				StartDateTime,
				case when endDateTime IS NULL THEN @endDateTimeToUseForCalc ELSE endDateTime END as endDateTime,
				[status],
				JobCodeID,
				ClockOutStation_ID,
				Hourly_Wage,
				OvertimeHourly_Wage,
				0 as NumMinutesBreak,
				0 as OvertimeMinutesAtTimeAndAHalf,
				0 as OvertimeMinutesAtDoubleTime,
				0 as DaysInARow,
				0 as NumMinutesBreakPaid,
				0 as NumMinutesBreakUnpaid,
				0 as Total_Cash_Sales,
				0 as Cash_Tips_Taken
			from Time_Clock
			where 			        
				store_id = @storeId and StartDateTime >= @startDateForPayPeriod 
				and StartDateTime < @startDateTime -- it's less than start date time because we will already have that
	
		-- for the calcs they have to be in order, so we take the two inserts and sort them together
		-- into the #timeclock
		select * into #timeclock
			from #timeclockRaw
			order by cashier_Id, startDateTime, jobcodeId
				
		update #timeclock set payname = 
				isnull(emp.first_Name + ' ' +  emp.Last_Name,'undefined, ' + tc.Cashier_ID)
				from employee emp, #timeclock tc
				where emp.cashier_id = tc.cashier_id


		--- get the employee payroll number (even if we may not need it yet)
		update #timeclock set payroll_employee_number = emp.payroll_employee_number
				from Employee_AdditionalInfo emp, #timeclock tc
				where emp.cashier_id = tc.cashier_id

		--- set up the temporary #timeclockbreaks
		--- it's a one to many from the #timeclock to the timeclock breaks
		select 
			case when b.BreakEndDateTime IS NULL THEN '1' ELSE '0' END as IsBreakOpen,
			convert(varchar(10),'') as dateIn,
			convert(varchar(10),'') as startTime,
			convert(varchar(10),'') as endTime,
			convert(varchar(10),'') as dateOut,
			convert(varchar(20),'') as cashierId,
			convert(varchar(20),'') as payname,
			convert(varchar(20),'') as JobCodeId,
			convert(varchar(20),'') as jobcode_desc,
			convert(varchar(20),'') as transactionId,
			convert(varchar(20),'') as clockoutstation_id,
			case when b.paid = 1 THEN 'true' ELSE 'false' END as isPaidBreak,
			case when b.paid = 0 THEN 'true' ELSE 'false' END as isUnPaidBreak,
			b.* into #timeclockbreaks
			from Time_Clock_Breaks b, #timeclock t
			where b.ID = t.ID

		update #timeclockbreaks
			set BreakEndDateTime =  @endDateTimeToUseForCalc
			where BreakEndDateTime is null

		update #timeclockbreaks					
			set NumMinutesBreak = DATEDIFF(mi, BreakStartDateTime, BreakEndDateTime)			
			where IsBreakOpen = 1 and Paid = 0

		update #timeclockbreaks					
			set dateIn = FORMAT( BreakStartDateTime, 'MM/dd/yyyy', 'en-US' ),
				dateOut = FORMAT( BreakEndDateTime, 'MM/dd/yyyy', 'en-US' ),
				startTime = FORMAT( BreakStartDateTime, 'HH:mm', 'en-US' ),
				endTime = FORMAT( BreakEndDateTime, 'HH:mm', 'en-US' )


		--- if the break is open, then we have to ADD the NumMinutesBreak for OPEN breaks
		--- it's assumed that there is ONLY 1 open break
		update #timeclock					
			set NumMinutesBreak = t.NumMinutesBreak + DATEDIFF(mi, BreakStartDateTime, BreakEndDateTime)
			from #timeclock t, #timeclockbreaks b
			where t.id = b.Id
				and b.Paid = 0
				and b.IsBreakOpen = 1

		-- updates for logged in employees -----------------------------		
		
		--- calculate the minutes, using the incoming enddate time (now)
		update #timeclock
			set TotalMinutes = DATEDIFF(mi, StartDateTime, endDateTime),
				NumMinutes = DATEDIFF(mi, StartDateTime, endDateTime)
			where IsStillLoggedIn = 1


		--- get the jobcode name 
		update #timeclock
			set jobcode_desc = JobCode.JobCodeName
			from #timeclock, JobCode
			where #timeclock.JobCodeID = jobCode.JobCodeID
			

		--- update for breaks, note it's a sum on the timeclockbreaks as there may be one than one break				
		update #timeclock
			set NumMinutesBreak = tb.numMinutesBreak 
			from #timeClock tc, (select id, sum(NumMinutesBreak) as numMinutesBreak 
								from #timeclockbreaks
								where Paid = 0
								group by id
								) tb
			where tc.id = tb.ID

		update #timeclock
			set OrigTotalMinutes = DATEDIFF(mi, StartDateTime, EndDateTime)

		update #timeclock
			set TotalMinutes = iif(OrigTotalMinutes - NumMinutesBreak > 0,OrigTotalMinutes - NumMinutesBreak,0),
				NumMinutes = iif(OrigTotalMinutes - NumMinutesBreak > 0,OrigTotalMinutes - NumMinutesBreak,0)
	
		-- update for everybody, now that we have num minutes
		update #timeclock
			set TotalHours = Convert(Decimal(8,2), TotalMinutes/convert(decimal(5,2),60))
				
		-- specific record vars
		declare @cCashierId varchar(20)
		declare @cIsStillLoggedIn int
		Declare @cTotalMinutes Decimal(8,2)
		Declare @cPeriodNo int
		Declare @cId int
		declare @cStartDateTime DateTime

		declare @minutesForPeriod Decimal(8,2)
		-- 
		declare @fortyHoursInMinutes Decimal(8,2)
		select @fortyHoursInMinutes = 2400 ;

		declare @lastPeriodBreak varchar(30)
		select @lastPeriodBreak = '~'

		declare @lastSequentialDaysBreak varchar(30)
		select @lastSequentialDaysBreak = '~'
		declare @currentDaysBreak varchar(30)

		-- weekly method of overtime calculation -----------------------------
		if @overtimeCalculationMethod = 0 begin 
			
			update #timeclock set periodNo = convert(int,DateDiff(d, @startDateForPayPeriod, startDateTime) / 7)

			DECLARE db_cursor CURSOR FOR  
			SELECT cashier_id, IsStillLoggedIn, TotalMinutes, PeriodNo, Id
				FROM #timeclock 			
				order by cashier_id, periodNo, StartDateTime

			OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId
		
			WHILE @@FETCH_STATUS = 0   
			BEGIN   					
					declare @regTimeBucket Decimal(8,2)
					declare @otTimeBucket Decimal(8,2)
					declare @amtToAllocate2 Decimal(8,2)
					declare @minutesNeededToGetTo40 Decimal(8,2)

					select @amtToAllocate2 = @cTotalMinutes
					select @regTimeBucket = 0
					select @otTimeBucket = 0
					
					if( @lastPeriodBreak <> @cCashierId + convert(varchar(10),@cPeriodNo)) begin
						select @lastPeriodBreak = @cCashierId + convert(varchar(10),@cPeriodNo)					
						select @minutesForPeriod = 0
					end					
				
					--- if it all falls into overtime, before we add the accumulator
					if (@minutesForPeriod >= @fortyHoursInMinutes) begin
						-- were over the forty hour mark, prior to this entry, so it's all overtime
						select @otTimeBucket = @cTotalMinutes						
					end else begin
						-- how many minutes to we need to get it to 40
						select @minutesNeededToGetTo40 = iif(@fortyHoursInMinutes - @minutesForPeriod > 0,@fortyHoursInMinutes - @minutesForPeriod,0 )
						if @minutesNeededToGetTo40 > @amtToAllocate2 begin
							select @regTimeBucket = @amtToAllocate2
						end else begin
							select @regTimeBucket = iif(@cTotalMinutes - @minutesNeededToGetTo40 > 0,@minutesNeededToGetTo40, @cTotalMinutes)
							select @otTimeBucket = @cTotalMinutes - @regTimeBucket
						end 
					end
			
					update #timeclock set RegularMinutes = @regTimeBucket, OvertimeMinutes = @otTimeBucket
						where id = @cId
			
					select @minutesForPeriod = @minutesForPeriod + @cTotalMinutes				
			
					FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId			
			END   

			CLOSE db_cursor   
			DEALLOCATE db_cursor
						
			update #timeclock set wages = (RegularMinutes / 60) * Hourly_Wage,
					OvertimeWagesEarned = (OvertimeMinutes / 60) * OverTimeHourly_Wage,
					overtimeHours = OvertimeMinutes/@SixtyInDecimal					
		end 
		-- end of weekly overtime calculation
		
		-- daily method of overtime calculation -----------------------------
		if @overtimeCalculationMethod = 1 begin 			
			update #timeclock set periodNo = DATEPART(DAYOFYEAR, StartDateTime)
			
			-- under 8 hours is standard rate
			-- 8 - 12 is 1.5 standard rate
			declare @8HourThresholdInMinutes Decimal(8,2)
			select @8HourThresholdInMinutes = 480

			-- 12 and over is double time
			declare @12HourThresholdInMinutes Decimal(8,2)
			select @12HourThresholdInMinutes = 720

			declare @otTimeAndAHalf Decimal(8,2)
			declare @otDoubleTime Decimal(8,2)

			declare @workedDaysInARow int
			declare @workedDaysInARowDate DateTime 

			DECLARE db_cursor CURSOR FOR  
			SELECT cashier_id, IsStillLoggedIn, TotalMinutes, PeriodNo, Id, StartDateTime
				FROM #timeclock 			
				order by cashier_id, periodNo, StartDateTime

			OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId, @cStartDateTime
		
			WHILE @@FETCH_STATUS = 0   
			BEGIN   
					--- update for current record
					select @otTimeAndAHalf = 0
					select @otDoubleTime = 0
					select @regTimeBucket = 0
					
					--- temp vars
					declare @minutesNeededToGetTo8 Decimal(8,2)
					declare @minutesNeededToGetTo12 Decimal(8,2)

					--- this is for a period break (per day, in daily)
					if( @lastPeriodBreak <> @cCashierId + convert(varchar(10),@cPeriodNo)) begin
						select @lastPeriodBreak = @cCashierId + convert(varchar(10),@cPeriodNo)					
						select @minutesForPeriod = 0						
					end
					
					--- set up for 7th day worked in a row
					declare @payPeriod int
					declare @breakDateFor7thDate datetime 
					declare @currentDateFor7thDate datetime 
					select @payPeriod = convert(int,DateDiff(d, @startDateForPayPeriod, @cStartDateTime) / 7)					

					select @currentDaysBreak = @ccashierId + '.' + Convert(varchar(4), @payPeriod)					
					if @lastSequentialDaysBreak <> @currentDaysBreak begin					
						select @lastSequentialDaysBreak = @currentDaysBreak						
						select @workedDaysInARow = 0
						select @breakDateFor7thDate = [dbo].getStartDateOfPayPeriod(@cStartDateTime,@workweekStartDay)	
					end
					
					if DatePart(dy,@cStartDateTime) = DatePart(dy,@breakDateFor7thDate) begin
						select @workedDaysInARow = @workedDaysInARow + 1
						select @breakDateFor7thDate = DateAdd(dd,1, @breakDateFor7thDate)
					end 

					declare @diff Decimal(8,2)
					declare @amtToAllocate Decimal(8,2)					
					select @amtToAllocate = @cTotalMinutes
					
					select @minutesNeededToGetTo8 = @8HourThresholdInMinutes - @minutesForPeriod
					
					if @workedDaysInARow = 7 begin
						select @otTimeAndAHalf = iif(@amtToAllocate <= @minutesNeededToGetTo8, @amtToAllocate, @minutesNeededToGetTo8)
						select @amtToAllocate = @amtToAllocate - @otTimeAndAHalf
						select @otDoubleTime = iif(@amtToAllocate > 0, @amtToAllocate, 0)
					end else begin
						if @minutesNeededToGetTo8 > 0 begin						
							select @regTimeBucket = iif(@minutesNeededToGetTo8 - @amtToAllocate > 0,@amtToAllocate, @minutesNeededToGetTo8)
							
							select @amtToAllocate = @amtToAllocate - @regTimeBucket   
							--select @cId, @regTimeBucket, @amtToAllocate
							--- add to summary total
							select @minutesForPeriod = @minutesForPeriod + @regTimeBucket				
						end 
					 
						--- were in the 8-12 range
						select @minutesNeededToGetTo12 = @12HourThresholdInMinutes - @minutesForPeriod
						if @minutesNeededToGetTo12 > 0 begin						
							select @otTimeAndAHalf = iif(@minutesNeededToGetTo12 - @amtToAllocate > 0, @amtToAllocate, @minutesNeededToGetTo12)
							select @amtToAllocate = @amtToAllocate - @otTimeAndAHalf   
						
							--- add to summary total
							select @minutesForPeriod = @minutesForPeriod + @otTimeAndAHalf				
						end 

						if @amtToAllocate > 0 begin
							select @otDoubleTime = @amtToAllocate
							select @minutesForPeriod = @minutesForPeriod + @otDoubleTime
							select @amtToAllocate = 0
						end
					end
					update #timeclock set RegularMinutes = @regTimeBucket,
							OvertimeMinutesAtTimeAndAHalf = @otTimeAndAHalf,
							OvertimeMinutesAtDoubleTime = @otDoubleTime,
							DaysInARow = @workedDaysInARow
							where Id = @cId

					FETCH NEXT FROM db_cursor INTO @cCashierId, @cIsStillLoggedIn, @cTotalMinutes, @cPeriodNo, @cId, @cStartDateTime
			END   

			CLOSE db_cursor   
			DEALLOCATE db_cursor

			update #timeclock set wages = (RegularMinutes / 60) * Hourly_Wage,
					OvertimeWagesAtTimeAndAHalf = (OvertimeMinutesAtTimeAndAHalf / 60) * (hourly_wage * 1.5),
					OvertimeWagesAtDoubleTime = (OvertimeMinutesAtDoubleTime / 60) * hourly_wage * 2

			update #timeclock set OvertimeWagesEarned = OvertimeWagesAtTimeAndAHalf + OvertimeWagesAtDoubleTime,
					OvertimeMinutes = OvertimeMinutesAtTimeAndAHalf + OvertimeMinutesAtDoubleTime,
					overtimeHours = (OvertimeMinutesAtDoubleTime + OvertimeMinutesAtTimeAndAHalf)/@SixtyInDecimal
		end

		update #timeClock	
				set startDate = FORMAT( StartDateTime, 'MM/dd/yyyy', 'en-US' ),
					startTime = FORMAT( StartDateTime, 'HH:mm', 'en-US' ),
					endTime = FORMAT( EndDateTime, 'HH:mm', 'en-US' ),
					dateIn = FORMAT( StartDateTime, 'MM/dd/yyyy', 'en-US' ),
					dateOut = FORMAT( EndDateTime, 'MM/dd/yyyy', 'en-US' ),
					doubleTimeRate = hourly_wage * 2,
					regularHours = RegularMinutes / @SixtyInDecimal
					

		-- add reference fields to breaks
		update #timeclockbreaks
			set cashierId = t.Cashier_ID,
				payname = t.payname,
				JobCodeId = t.JobCodeID,
				jobcode_desc = t.jobcode_desc,
				clockoutstation_id = t.ClockOutStation_ID,
				transactionId = t.id
			from #timeclockbreaks b, #timeclock t
				where b.id = t.id
		
		update #timeclock 
			set endTime = '',
				dateOut = ''				
			where IsStillLoggedIn = 1
			
		update #timeclockbreaks
			set endTime = '',
			DateOut = ''
			where IsBreakOpen = 1

		update #timeclock
			set transactionId = convert(varchar(10),Convert(int,id) + 5000000)

		update #timeclockbreaks
			set transactionId = convert(varchar(10),Convert(int,id) + 5000000)
		
		select transactionId as trxId, cashier_id as cashierId,* from #timeclock 
			where isOutOfRange = 0  -- were now bringing in records for the entire payperiod, to properly calc overtime, if it's zero it's in the range
			order by cashier_id, periodNo, StartDateTime

		select * from #timeclockbreaks 
			where id in (select id from #timeclock where isOutOfRange = 0)
			order by cashierId, transactionId
			


		--- diag

		--select 'x',id, totalminutes,OrigTotalMinutes, numMinutesBreak, NumMinutes, StartDateTime, endDateTime, isOutOfRange from #timeclock 
		--	where Cashier_ID = '100106'
		--	order by cashier_Id, startDateTime, jobcodeId
		
		--select 'z',cashier_Id, sum(totalminutes) as totalminutes , sum(overtimeMinutes) as overtimeMinutes
		--	from #timeclock
		--	group by cashier_Id

    set nocount off
GO
/****** Object:  StoredProcedure [dbo].[RetailSales]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[RetailSales](@presentdate1 datetime,@presentDate2 datetime,@lastdate1 datetime,@lastdate2 datetime) AS SELECT     storedescription, type, ISNULL(SUM(totalsales),0) AS totalsales,description,ascii(description)+len(description) as index1,1 as index2 FROM         (SELECT     setup.Store_ID + '  ' + setup.Store_Description AS storedescription, categories.Description AS description, ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'LY' AS type   FROM          Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS inventory INNER JOIN  Departments AS Departments RIGHT OUTER JOIN Categories AS categories LEFT OUTER  JOIN Setup AS setup ON categories.Store_ID = setup.Store_ID ON Departments.Store_ID = categories.Store_ID AND departments.SubType = categories.Cat_ID ON inventory.Dept_ID = Departments.Dept_ID AND inventory.Store_ID = Departments.Store_ID ON CC.ItemNum = inventory.ItemNum AND CC.Store_ID = inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID AND I.Status = 'C' AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @lastdate1 AND @lastdate2) GROUP BY setup.Store_ID, setup.Store_Description, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), categories.Description, CC.Invoice_Number) AS t3 GROUP BY storedescription, type, description  UNION SELECT     storedescription, type, ISNULL(SUM(totalsales),0) AS totalsales, 'Total' AS Description,10000 as index1,1 as index2 FROM         (SELECT     setup.Store_ID + '  ' + setup.Store_Description AS storedescription, categories.Description AS description, ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'LY' AS type, CC.Invoice_Number AS customers FROM          Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS inventory INNER JOIN Departments AS Departments RIGHT OUTER  JOIN Categories AS categories LEFT OUTER JOIN Setup AS setup ON categories.Store_ID = setup.Store_ID ON Departments.Store_ID = categories.Store_ID AND Departments.SubType = categories.Cat_ID ON inventory.Dept_ID = Departments.Dept_ID AND inventory.Store_ID = Departments.Store_ID ON CC.ItemNum = inventory.ItemNum AND CC.Store_ID = inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID AND I.Status = 'C' AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @lastdate1 AND @lastdate2) GROUP BY setup.Store_ID, setup.Store_Description, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), categories.Description, CC.Invoice_Number) AS t3 GROUP BY storedescription, type UNION SELECT     storedescription, type, ISNULL(COUNT(DISTINCT customers),0) AS totalsales , '#of Cust' AS Description,10001 as index1,1 as index2 FROM         (SELECT     setup.Store_ID + '  ' + setup.Store_Description AS storedescription, categories.Description AS description, ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'LY' AS type, CC.Invoice_Number AS customers  FROM          Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS inventory INNER JOIN Departments AS Departments RIGHT OUTER JOIN Categories AS categories LEFT OUTER JOIN Setup AS setup ON categories.Store_ID = setup.Store_ID ON Departments.Store_ID = categories.Store_ID AND Departments.SubType = categories.Cat_ID ON inventory.Dept_ID = Departments.Dept_ID AND inventory.Store_ID = Departments.Store_ID ON CC.ItemNum = inventory.ItemNum AND CC.Store_ID = inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID AND I.Status = 'C' AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @lastdate1 AND @lastdate2) GROUP BY setup.Store_ID, setup.Store_Description, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), categories.Description, CC.Invoice_Number) AS t3 GROUP BY storedescription, type UNION SELECT     storedescription, type, ISNULL(SUM(totalsales) / COUNT(DISTINCT customers),0) AS totalsales, 'Avg Sale' AS Description,10002 as index1,1 as index2 FROM         (SELECT     setup.Store_ID + '  ' + setup.Store_Description AS storedescription, categories.Description AS description, ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'LY' AS type, CC.Invoice_Number AS customers FROM          Invoice_Totals AS I INNER JOIN  Invoice_Itemized AS CC INNER JOIN Inventory AS inventory INNER JOIN Departments AS Departments RIGHT OUTER JOIN Categories AS categories LEFT OUTER JOIN Setup AS setup ON categories.Store_ID = setup.Store_ID ON Departments.Store_ID = categories.Store_ID AND Departments.SubType = categories.Cat_ID ON inventory.Dept_ID = Departments.Dept_ID AND inventory.Store_ID = Departments.Store_ID ON CC.ItemNum = inventory.ItemNum AND CC.Store_ID = inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID AND I.Status = 'C' AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @lastdate1 AND  @lastdate2) GROUP BY setup.Store_ID, setup.Store_Description, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), categories.Description, CC.Invoice_Number) AS t3 GROUP BY storedescription, type    UNION SELECT     storedescription, type, ISNULL(SUM(totalsales),0) AS totalsales, description,ascii(description)+len(description) as index1,0 as index2 FROM         (SELECT     setup.Store_ID + '  ' + setup.Store_Description AS storedescription, categories.Description AS description, ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'TY' AS type FROM          Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS inventory INNER JOIN Departments AS Departments RIGHT OUTER JOIN Categories AS categories LEFT OUTER JOIN Setup AS setup ON categories.Store_ID = setup.Store_ID ON Departments.Store_ID = categories.Store_ID AND Departments.SubType = categories.Cat_ID ON inventory.Dept_ID = Departments.Dept_ID AND inventory.Store_ID = Departments.Store_ID ON CC.ItemNum = inventory.ItemNum AND CC.Store_ID = inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID AND I.Status = 'C' AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @Presentdate1 AND   @Presentdate2)   GROUP BY setup.Store_ID, setup.Store_Description, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), categories.Description,  CC.Invoice_Number) AS t3 GROUP BY storedescription, type, description UNION SELECT     storedescription, type, ISNULL(SUM(totalsales),0) AS totalsales, 'Total' AS Description,10000 as index1,0 as index2 FROM         (SELECT     setup.Store_ID + '  ' + setup.Store_Description AS storedescription, categories.Description AS description,  ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'TY' AS type, CC.Invoice_Number AS customers  FROM          Invoice_Totals AS I INNER JOIN     Invoice_Itemized AS CC INNER JOIN  Inventory AS inventory INNER JOIN  Departments AS Departments RIGHT OUTER JOIN  Categories AS categories LEFT OUTER JOIN  Setup AS setup ON categories.Store_ID = setup.Store_ID ON Departments.Store_ID = categories.Store_ID AND  Departments.SubType = categories.Cat_ID ON inventory.Dept_ID = Departments.Dept_ID AND inventory.Store_ID = Departments.Store_ID ON  CC.ItemNum = inventory.ItemNum AND CC.Store_ID = inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID  AND I.Status = 'C' AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @PresentDate1 AND  @PresentDate2) GROUP BY setup.Store_ID, setup.Store_Description, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), categories.Description,  CC.Invoice_Number) AS t3 GROUP BY storedescription, type UNION SELECT     storedescription, type, ISNULL(COUNT(DISTINCT customers),0) AS totalsales , '#of Cust' AS Description,10001 as index1,0 as index2 FROM         (SELECT     setup.Store_ID + '  ' + setup.Store_Description AS storedescription, categories.Description AS description,      ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'TY' AS type, CC.Invoice_Number AS customers   FROM          Invoice_Totals AS I INNER JOIN  Invoice_Itemized AS CC INNER JOIN  Inventory AS inventory INNER JOIN   Departments AS Departments RIGHT OUTER JOIN  Categories AS categories LEFT OUTER JOIN Setup AS setup ON categories.Store_ID = setup.Store_ID ON Departments.Store_ID = categories.Store_ID AND   Departments.SubType = categories.Cat_ID ON inventory.Dept_ID = Departments.Dept_ID AND inventory.Store_ID = Departments.Store_ID ON CC.ItemNum = inventory.ItemNum AND CC.Store_ID = inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID AND I.Status = 'C' AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @Presentdate1 AND  @Presentdate2) GROUP BY setup.Store_ID, setup.Store_Description, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), categories.Description, CC.Invoice_Number) AS t3 GROUP BY storedescription, type UNION SELECT     storedescription, type, ISNULL(SUM(totalsales) / COUNT(DISTINCT customers),0) AS totalsales, 'Avg Sale' AS Description,10002 as index1,0 as index2 FROM         (SELECT     setup.Store_ID + '  ' + setup.Store_Description AS storedescription, categories.Description AS description,  ROUND(SUM((CC.PricePer * CC.Quantity) * (1 - I.Discount)), 3) AS totalsales, 'TY' AS type, CC.Invoice_Number AS customers FROM          Invoice_Totals AS I INNER JOIN Invoice_Itemized AS CC INNER JOIN Inventory AS inventory INNER JOIN Departments AS Departments RIGHT OUTER JOIN Categories AS categories LEFT OUTER JOIN Setup AS setup ON categories.Store_ID = setup.Store_ID ON Departments.Store_ID = categories.Store_ID AND Departments.SubType = categories.Cat_ID ON inventory.Dept_ID = Departments.Dept_ID AND inventory.Store_ID = Departments.Store_ID ON CC.ItemNum = inventory.ItemNum AND CC.Store_ID = inventory.Store_ID ON I.Invoice_Number = CC.Invoice_Number AND I.Store_ID = CC.Store_ID AND I.Status = 'C' AND (CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME) IS NOT NULL) AND (I.DateTime BETWEEN @Presentdate1 AND  @Presentdate2)                      GROUP BY setup.Store_ID, setup.Store_Description, CAST(FLOOR(CAST(I.DateTime AS FLOAT)) AS DATETIME), categories.Description, CC.Invoice_Number) AS t3 GROUP BY storedescription, type     UNION SELECT     storedescription, Type, ISNULL(SUM(goalamount),0) AS totalsales, description,ascii(description)+len(description) as index1,2 as index2 FROM         (SELECT     se.Store_ID + '  ' + se.Store_Description AS storedescription, ce.Description AS description, bu.Goal_Amount AS goalamount, 'Plan' AS Type  FROM          Budget_Sales AS bu RIGHT OUTER JOIN  Categories AS ce LEFT OUTER JOIN Setup AS se ON ce.Store_ID = se.Store_ID ON bu.Store_ID = ce.Store_ID AND bu.Cat_ID = ce.Cat_ID AND bu.DateTime BETWEEN @presentdate1 AND @presentdate2 GROUP BY se.Store_ID, se.Store_Description, bu.Goal_Amount, ce.Description, bu.DateTime) AS t1 GROUP BY storedescription, description, Type UNION SELECT     storedescription, Type, ISNULL(SUM(goalamount),0) AS totalsales, 'Total' as Description,10000 as index1,2 as index2 FROM         (SELECT     se.Store_ID + '  ' + se.Store_Description AS storedescription, ce.Description AS description, bu.Goal_Amount AS goalamount, 'Plan' AS Type  FROM          Budget_Sales AS bu RIGHT OUTER JOIN  Categories AS ce LEFT OUTER JOIN  Setup AS se ON ce.Store_ID = se.Store_ID ON bu.Store_ID = ce.Store_ID AND bu.Cat_ID = ce.Cat_ID AND bu.DateTime BETWEEN @presentdate1 AND @presentdate2 GROUP BY se.Store_ID, se.Store_Description, bu.Goal_Amount, ce.Description, bu.DateTime) AS t1 GROUP BY storedescription, Type UNION SELECT     storedescription, Type,0 as totalsales, '#of Cust' as Description,10001 as index1,2 as index2 FROM         (SELECT     se.Store_ID + '  ' + se.Store_Description AS storedescription, ce.Description AS description, 'Plan' AS Type  FROM          Budget_Sales AS bu RIGHT OUTER JOIN Categories AS ce LEFT OUTER JOIN Setup AS se ON ce.Store_ID = se.Store_ID ON bu.Store_ID = ce.Store_ID AND bu.Cat_ID = ce.Cat_ID AND bu.DateTime BETWEEN @presentdate1 AND @presentdate2 GROUP BY se.Store_ID, se.Store_Description, bu.Goal_Amount, ce.Description, bu.DateTime) AS t1 GROUP BY storedescription, Type UNION SELECT     storedescription, Type,0 as totalsales,  'Avg Sale' as Description,10002 as index1,2 as index2 FROM         (SELECT     se.Store_ID + '  ' + se.Store_Description AS storedescription, ce.Description AS description, 'Plan' AS Type FROM          Budget_Sales AS bu RIGHT OUTER JOIN  Categories AS ce LEFT OUTER JOIN Setup AS se ON ce.Store_ID = se.Store_ID ON bu.Store_ID = ce.Store_ID AND bu.Cat_ID = ce.Cat_ID AND bu.DateTime BETWEEN @presentdate1 AND @presentdate2 GROUP BY se.Store_ID, se.Store_Description, bu.Goal_Amount, ce.Description, bu.DateTime) AS t1 GROUP BY storedescription, Type
GO
/****** Object:  StoredProcedure [dbo].[sp_CreateDefaults]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_CreateDefaults]

AS
BEGIN TRAN

-- Find all columns that don't have a default value

-- Loop through all tables
DECLARE TableCursor CURSOR FOR
SELECT name AS TableName, object_id as TableObjectID FROM sys.tables ORDER BY TableName ASC;

DECLARE @TableName VARCHAR(255);
DECLARE @TableObjectID INT;

OPEN TableCursor;

FETCH NEXT FROM TableCursor INTO @TableName, @TableObjectID;

WHILE @@FETCH_STATUS = 0
BEGIN
  -- Loop through the columns
  DECLARE ColumnCursor CURSOR FOR
    SELECT sys_columns.name AS ColumnName, sys_types.name as TypeName
    FROM sys.columns sys_columns INNER JOIN sys.types sys_types on sys_columns.user_type_id = sys_types.user_type_id
                                                               -- Fetch the columns
    WHERE sys_columns.object_id = @TableObjectID AND           --   in the current table
          sys_columns.default_object_id = 0                    --   that have no default
    ORDER BY ColumnName ASC;                                   --   and order them by name

  OPEN ColumnCursor;

  DECLARE @ColumnName VARCHAR(255);
  DECLARE @TypeName VARCHAR(255);
  DECLARE @AlterTableStatement VARCHAR(8000);

  FETCH NEXT FROM ColumnCursor INTO @ColumnName, @TypeName;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    DECLARE @DefaultValueString VARCHAR(8000)

    SET @DefaultValueString = 'NODEFAULT'

    -- Set the default value
    -- Numeric types
    IF @TypeName = 'bit'
      BEGIN
        SET @DefaultValueString = '0';
      END
    ELSE IF @TypeName = 'smallint'
      BEGIN
        SET @DefaultValueString = '0';
      END
    ELSE IF @TypeName = 'bigint'
      BEGIN
        SET @DefaultValueString = '0';
      END
    ELSE IF @TypeName = 'decimal'
      BEGIN
        SET @DefaultValueString = '0';
      END
    ELSE IF @TypeName = 'int'
      BEGIN
        SET @DefaultValueString = '0';
      END
    ELSE IF @TypeName = 'float'
      BEGIN
        SET @DefaultValueString = '0';
      END
    ELSE IF @TypeName = 'real'
      BEGIN
        SET @DefaultValueString = '0';
      END
	--ELSE IF @TypeName = 'uniqueidentifier'
      --BEGIN
        --SET @DefaultValueString = 'newID()';
      --END
    -- String types
    ELSE IF @TypeName = 'nvarchar'
      BEGIN
        SET @DefaultValueString = '''''';
      END
    ELSE IF @TypeName = 'varchar'
      BEGIN
        SET @DefaultValueString = '''''';
      END
    --ELSE IF @TypeName = 'ntext'
      --BEGIN
        --SET @DefaultValueString = '''''';
      --END
    -- Date/Time types
    ELSE IF @TypeName = 'datetime'
      BEGIN
        SET @DefaultValueString = 'NULL';
      END
    ELSE IF @TypeName = 'smalldatetime'
      BEGIN
        SET @DefaultValueString = 'NULL';
      END
    -- Money types
    ELSE IF @TypeName = 'money'
      BEGIN
        SET @DefaultValueString = '0';
      END

    IF @DefaultValueString = 'NODEFAULT'
      BEGIN
        PRINT 'Error!  Unexpected type ' + @TypeName;
      END
    ELSE IF @ColumnName = 'CreateDate' OR @ColumnName = 'ModifiedDate' OR @ColumnName = 'InsertOriginatorID' OR @ColumnName = 'UpdateOriginatorID' OR @ColumnName = 'DeleteDate' OR @ColumnName = 'DeleteOriginatorID' OR @ColumnName = 'UpdateTimestamp' OR @ColumnName = 'CreateTimestamp' OR @ColumnName = 'DeleteTimestamp'
		BEGIN
			PRINT 'Skipping setting a default for table: [' + @TableName + '] column:[' + @ColumnName + ']';
		END
	ELSE
	  BEGIN
		-- Generate SQL to configure the default value constraint for this column
		--PRINT @TableName + '.' + @ColumnName + ' [' + @TypeName + '] has no default value';
		-- [RCH 5/22/2007] -- I needed to append the tablename to the end of the constraint name because there was a conflict between:
		--						Inventory.Reorder_Cost AND Inventory_Reorder.Cost
		--						They both tried creating the constraint 'Default_Inventory_Reorder_Cost'
		SET @AlterTableStatement = 'ALTER TABLE [dbo].[' + @TableName + '] ADD CONSTRAINT [DF_' + @TableName + '_' + @ColumnName + '_' + @TableName + '] DEFAULT ' + @DefaultValueString + ' FOR [' + @ColumnName + '];';
	--	if OBJECTPROPERTY(OBJECT_ID(N'Default_' + @TableName + '_' + @ColumnName + ''), N'CnstIsColumn') = 1
	--		EXEC ('ALTER TABLE [dbo].[' + @TableName + '] DROP CONSTRAINT [Default_' + @TableName + '_' + @ColumnName + ']')

		PRINT @AlterTableStatement
		BEGIN TRY
			EXEC (@AlterTableStatement)
		END TRY
		BEGIN CATCH
		END CATCH
	  END
		
    FETCH NEXT FROM ColumnCursor INTO @ColumnName, @TypeName;
  END

  CLOSE ColumnCursor;
  DEALLOCATE ColumnCursor;

  FETCH NEXT FROM TableCursor INTO @TableName, @TableObjectID;
END

CLOSE TableCursor;
DEALLOCATE TableCursor;

COMMIT TRAN
GO
/****** Object:  StoredProcedure [dbo].[sp_CreateTracking]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[sp_CreateTracking]
	@SyncID INT
AS

EXEC('sp_msforeachtable ''ALTER TABLE ? DISABLE TRIGGER ALL ''');

DECLARE @CurrentTableRowCount int;
DECLARE @MaxTableRowCount int;

DECLARE @SchemaName nvarchar(128);

DECLARE @ErrorNum int;

IF OBJECT_ID('tempdb..#AppTable') IS NOT NULL
BEGIN
   DROP TABLE #AppTable
END

CREATE TABLE #AppTable (AppTableID INT, SchemaName NVARCHAR(128)
                      , TableName NVARCHAR(128), EnableTracking BIT);

DECLARE @tableName NVARCHAR( 128 )
DECLARE @lastTableName NVARCHAR( 128 )
DECLARE @appTableRowCounter INT
DECLARE @ValidTable bit
SET @appTableRowCounter = 0
SET @lastTableName = ''
SET @ValidTable = 0

SELECT @tableName = MIN( [name] ) FROM sys.tables GROUP BY [name] ORDER BY [name] DESC

WHILE @tableName <> @lastTableName
BEGIN
    SET @appTableRowCounter = @appTableRowCounter + 1
    exec sp_IsValidTableForTracking @TableName= @tableName, @IsValid=@ValidTable OUTPUT
    
	IF @ValidTable = 1
		INSERT INTO #AppTable VALUES (@appTableRowCounter,N'dbo',@tableName,1);
	SET @lastTableName = @tableName
    SELECT @tableName = MIN( [name] ) FROM sys.tables WHERE [name] > @tableName GROUP BY [name] ORDER BY [name] DESC
END

---------------------------------------------------------------------------------------------
-- For each table with EnableTracking = 1: 
--	* Adds columns to track inserts and updates at the server.
--	* Create a "tombstones table" to track deletes at the server.
--	* Add a trigger to populate the tombstones table.
---------------------------------------------------------------------------------------------
-- Create a temp table to hold the ouput of sp_pkeys, which gets the keys for each table required by the app.
CREATE TABLE #AppTableKeys (TableQualifier nvarchar(128), TableOwner nvarchar(128)
							, TableName nvarchar(128), KeyColumnName nvarchar(128)
							, DataType nvarchar(128), Length SMALLINT
							, Scale SMALLINT
							, NumericPrecision SMALLINT, KeyColumnSequence SMALLINT
							, KeyName nvarchar(128));

DECLARE @SchemaAndTableName nvarchar(256);
DECLARE @ObjectId int;
DECLARE @EnableTracking bit;

DECLARE @CreateDateColumnName NVARCHAR(128);
DECLARE @ModifiedDateColumnName NVARCHAR(128);
DECLARE @CreateTimestampColumnName NVARCHAR(128);
DECLARE @UpdateTimestampColumnName NVARCHAR(128);
DECLARE @InsertOriginatorIdColumnName NVARCHAR(128);
DECLARE @UpdateOriginatorIdColumnName NVARCHAR(128);
DECLARE @DefaultConstraintName NVARCHAR(128);

DECLARE @AlterTableString NVARCHAR(4000);
DECLARE @UpdateTableString nvarchar(4000);

DECLARE @TombstoneTableName nvarchar(128);
DECLARE @CreateTombstoneTableString nvarchar(4000);
DECLARE @HasTombstoneTable bit;
DECLARE @CreateDeleteTimestampColumn bit;

DECLARE @DeleteTriggerName nvarchar(128);
DECLARE @InsertTriggerName nvarchar(128);
DECLARE @UpdateTriggerName nvarchar(128);
DECLARE @CreateDeleteTriggerString nvarchar(4000);
DECLARE @CreateInsertTriggerString nvarchar(4000);
DECLARE @CreateUpdateTriggerString nvarchar(4000);
DECLARE @CreateUpdateTriggerString2 nvarchar(4000);
DECLARE @TriggerKeyString nvarchar(4000);
DECLARE @HasInsertTrigger bit;
DECLARE @HasUpdateTrigger bit;

DECLARE @GetKeysString nvarchar(4000);
DECLARE @KeyDefinitionString nvarchar(4000);
DECLARE @ColumnDefinitionString nvarchar(4000);
DECLARE @KeyColumnName nvarchar(4000);
DECLARE @KeyColumnDataType nvarchar(4000);
DECLARE @KeyColumnLength smallint;
DECLARE @KeyColumnScale int;
DECLARE @KeyColumnNumericPrecision int;

DECLARE @KeyArray1 nvarchar(512);
DECLARE @KeyArray2 nvarchar(512);
DECLARE @KeyArray3 nvarchar(512);
DECLARE @KeyArrayValue nvarchar(512);
DECLARE @KeyArraySeparatorPosition int;

DECLARE @CurrentKeyRowCount int;
DECLARE @MaxKeyRowCount int;

SET @CreateDateColumnName = N'CreateDate';
SET @ModifiedDateColumnName = N'ModifiedDate';
SET @CreateTimestampColumnName = N'CreateTimestamp';
SET @UpdateTimestampColumnName = N'UpdateTimestamp';
SET @InsertOriginatorIdColumnName = N'InsertOriginatorId';
SET @UpdateOriginatorIdColumnName = N'UpdateOriginatorId';
SET @HasInsertTrigger = 0;
SET @HasUpdateTrigger = 0;
SET @HasTombstoneTable = 0;
SET @CreateDeleteTimestampColumn = 0;

-- The following variables were declared in the previous section of the script
SET @SchemaName = '';
SET @TableName = '';
SET @CurrentTableRowCount = 1;
SELECT @MaxTableRowCount = MAX(AppTableID) FROM #AppTable;

WHILE @CurrentTableRowCount <= @MaxTableRowCount
BEGIN
	SELECT @SchemaName = SchemaName, @TableName = TableName, @EnableTracking = EnableTracking 
		 , @SchemaAndTableName = @SchemaName + N'.' + @TableName
	FROM #AppTable
	WHERE AppTableID = @CurrentTableRowCount;
	
	IF @EnableTracking = 1
	BEGIN
		SET @ObjectId = OBJECT_ID(@SchemaAndTableName)

		-- ============================================================		
		-- Add an insert originator ID column if the table doesn't have one.
		-- ============================================================
		SET @DefaultConstraintName = 'DF_' + @TableName + '_' + @InsertOriginatorIdColumnName + '_' + @TableName;
		IF EXISTS (SELECT [name] FROM sys.columns 
					   WHERE [name] = @InsertOriginatorIdColumnName 
					   AND [object_id] = @ObjectId)
			BEGIN
				PRINT @SchemaAndTableName + N': already contains the tracking column ' + @InsertOriginatorIdColumnName + '.';
			END;
		ELSE
			BEGIN
				SET @AlterTableString = 'ALTER TABLE ' + @SchemaAndTableName + ' ADD ' + @InsertOriginatorIdColumnName + ' int ';
				EXEC (@AlterTableString);
				PRINT @SchemaAndTableName + N': added tracking column ' + @InsertOriginatorIdColumnName + '.';
			END;
		IF EXISTS(SELECT * FROM sys.default_constraints WHERE [parent_object_id]= '' + object_id(@TableName) + '' AND [name] = '' + @DefaultConstraintName + '')
			BEGIN
				EXEC('ALTER TABLE ' + @SchemaAndTableName + ' DROP CONSTRAINT ' + @DefaultConstraintName);
			END;
		EXEC('ALTER TABLE ' + @SchemaAndTableName + ' ADD CONSTRAINT ' + @DefaultConstraintName + ' DEFAULT ' + @SyncID + ' FOR [' + @InsertOriginatorIdColumnName + '];');
		-- ============================================================
		-- Add an update originator ID column if the table doesn't have one.
		-- ============================================================
		SET @DefaultConstraintName = 'DF_' + @TableName + '_' + @UpdateOriginatorIdColumnName + '_' + @TableName;
		IF EXISTS (SELECT [name] FROM sys.columns 
					   WHERE [name] = @UpdateOriginatorIdColumnName 
					   AND [object_id] = @ObjectId)
			BEGIN
				PRINT @SchemaAndTableName + N': already contains the tracking column ' + @UpdateOriginatorIdColumnName + '.';
			END;
		ELSE
			BEGIN
				SET @AlterTableString = 'ALTER TABLE ' + @SchemaAndTableName + ' ADD ' + @UpdateOriginatorIdColumnName + ' int ';
				EXEC (@AlterTableString);
				PRINT @SchemaAndTableName + N': added tracking column ' + @UpdateOriginatorIdColumnName + '.';
			END;
		IF EXISTS(SELECT * FROM sys.default_constraints WHERE [parent_object_id]= '' + object_id(@TableName) + '' AND [name] = '' + @DefaultConstraintName + '')
			BEGIN
				EXEC('ALTER TABLE ' + @SchemaAndTableName + ' DROP CONSTRAINT ' + @DefaultConstraintName);
			END;
		EXEC('ALTER TABLE ' + @SchemaAndTableName + ' ADD CONSTRAINT ' + @DefaultConstraintName + ' DEFAULT ' + @SyncID + ' FOR [' + @UpdateOriginatorIdColumnName + '];');
		-- Update these columns to have the default values
		EXEC('UPDATE ' + @SchemaAndTableName + ' SET [' + @InsertOriginatorIdColumnName + '] = ' + @SyncID + ' WHERE [' + @InsertOriginatorIdColumnName + '] IS NULL;');
		EXEC('UPDATE ' + @SchemaAndTableName + ' SET [' + @UpdateOriginatorIdColumnName + '] = ' + @SyncID + ' WHERE [' + @UpdateOriginatorIdColumnName + '] IS NULL;');

		-- ============================================================
		-- Add an UpdateTimestamp column if the table doesn't have one.
		-- ============================================================
		IF EXISTS (SELECT [name] FROM sys.columns 
					   WHERE [name] = @UpdateTimestampColumnName 
					   AND [object_id] = @ObjectId)
			BEGIN
				PRINT @SchemaAndTableName + N': already contains the tracking column ' + @UpdateTimestampColumnName  + '.';
			END;
		ELSE
			BEGIN
				SET @AlterTableString = 'ALTER TABLE ' + @SchemaAndTableName + ' ADD ' + @UpdateTimestampColumnName  + ' TIMESTAMP NOT NULL ';
				EXEC (@AlterTableString);
				PRINT @SchemaAndTableName + N': added tracking column ' + @UpdateTimestampColumnName  + '.';
			END;

		-- Create an index on the UpdateTimestamp column for better sync performance
		IF NOT EXISTS(SELECT * FROM sys.indexes WHERE [object_id]= '' + object_id(@TableName) + '' AND [name] = '' + 'IX_' + @TableName + '_' + @UpdateTimestampColumnName + '')
			BEGIN
				EXEC ('CREATE NONCLUSTERED INDEX IX_' + @TableName + '_' + @UpdateTimestampColumnName + ' ON dbo.' + @TableName + '(' + @UpdateTimestampColumnName + ')');
			END
			
		-- ============================================================
		-- Add an ModifiedDate column if the table doesn't have one.
		-- ============================================================
		IF EXISTS (SELECT [name] FROM sys.columns 
					   WHERE [name] = @ModifiedDateColumnName 
					   AND [object_id] = @ObjectId)
			BEGIN
				PRINT @SchemaAndTableName + N': already contains the tracking column ' + @ModifiedDateColumnName + '.';
			END;
		ELSE
			BEGIN
				SET @AlterTableString = 'ALTER TABLE ' + @SchemaAndTableName + ' ADD ' + @ModifiedDateColumnName + ' DATETIME ';
				EXEC (@AlterTableString);
				PRINT @SchemaAndTableName + N': added tracking column ' + @ModifiedDateColumnName + '.';
			END;
		
		SET @DefaultConstraintName = 'DF_' + @TableName + '_' + @ModifiedDateColumnName + '_' + @TableName;
		IF EXISTS(SELECT * FROM sys.default_constraints WHERE [parent_object_id]= '' + object_id(@TableName) + '' AND [name] = '' + @DefaultConstraintName + '')
			BEGIN
				EXEC('ALTER TABLE ' + @SchemaAndTableName + ' DROP CONSTRAINT ' + @DefaultConstraintName);
			END;
		
		EXEC('ALTER TABLE ' + @SchemaAndTableName + ' ADD CONSTRAINT ' + @DefaultConstraintName + ' DEFAULT GETUTCDATE() FOR [' + @ModifiedDateColumnName + '];')
		
		-- Disable any UPDATE triggers before updating the ModifiedDate column.
		SET @UpdateTableString = 'UPDATE ' + @SchemaAndTableName + ' SET ' + @ModifiedDateColumnName + ' = GETUTCDATE() WHERE ' + @ModifiedDateColumnName + ' IS NULL';
		EXEC (@UpdateTableString);
		PRINT @SchemaAndTableName + N': updated tracking column ' + @ModifiedDateColumnName + '.';		
		
		-- ============================================================
		-- Add an insert tracking column if the table doesn't have one.
		-- Then update the tracking column so that it has the same value as the ModifiedDate column.
		-- ============================================================
		IF EXISTS (SELECT [name] FROM sys.columns 
					   WHERE [name] = @CreateDateColumnName 
					   AND [object_id] = @ObjectId)
			BEGIN
				PRINT @SchemaAndTableName + N': already contains the tracking column ' + @CreateDateColumnName + '.';
			END;
		ELSE
			BEGIN
				SET @AlterTableString = 'ALTER TABLE ' + @SchemaAndTableName + ' ADD ' + @CreateDateColumnName + ' DATETIME ';
				EXEC (@AlterTableString);
				PRINT @SchemaAndTableName + N': added tracking column ' + @CreateDateColumnName + '.';
			END;
		
		SET @DefaultConstraintName = 'DF_' + @TableName + '_' + @CreateDateColumnName + '_' + @TableName;
		IF EXISTS(SELECT * FROM sys.default_constraints WHERE [parent_object_id]= '' + object_id(@TableName) + '' AND [name] = '' + @DefaultConstraintName + '')
			BEGIN
				EXEC('ALTER TABLE ' + @SchemaAndTableName + ' DROP CONSTRAINT ' + @DefaultConstraintName);
			END
		
		EXEC('ALTER TABLE ' + @SchemaAndTableName + ' ADD CONSTRAINT ' + @DefaultConstraintName + ' DEFAULT GetUTCDate() FOR [' + @CreateDateColumnName + '];');
			
		-- Disable any UPDATE triggers before updating the CreateDate column.
		SET @UpdateTableString = 'UPDATE ' + @SchemaAndTableName + ' SET ' + @CreateDateColumnName + ' = ModifiedDate WHERE ' + @CreateDateColumnName + ' IS NULL';
		EXEC (@UpdateTableString);
		PRINT @SchemaAndTableName + N': updated tracking column ' + @CreateDateColumnName + '.';		
			
		-- ============================================================
		-- Add a CreateTimestamp tracking column if the table doesn't have one.
		-- ============================================================
		IF EXISTS (SELECT [name] FROM sys.columns 
					   WHERE [name] = @CreateTimestampColumnName 
					   AND [object_id] = @ObjectId)
			BEGIN
				PRINT @SchemaAndTableName + N': already contains the tracking column ' + @CreateTimestampColumnName + '.';
			END;
		ELSE
			BEGIN
				SET @AlterTableString = 'ALTER TABLE ' + @SchemaAndTableName + ' ADD ' + @CreateTimestampColumnName + ' BIGINT ';
				EXEC (@AlterTableString);
				PRINT @SchemaAndTableName + N': added tracking column ' + @CreateTimestampColumnName + '.';
			END;
		
		SET @DefaultConstraintName = 'DF_' + @TableName + '_' + @CreateTimestampColumnName + '_' + @TableName;
		IF EXISTS(SELECT * FROM sys.default_constraints WHERE [parent_object_id]= '' + object_id(@TableName) + '' AND [name] = '' + @DefaultConstraintName + '')
			BEGIN
				EXEC('ALTER TABLE ' + @SchemaAndTableName + ' DROP CONSTRAINT ' + @DefaultConstraintName);
			END
		
		EXEC('ALTER TABLE ' + @SchemaAndTableName + ' ADD CONSTRAINT ' + @DefaultConstraintName + ' DEFAULT CAST(@@DBTS AS BIGINT)+1 FOR [' + @CreateTimestampColumnName + '];');

		EXEC('UPDATE ' + @SchemaAndTableName + ' SET ' + @CreateTimestampColumnName + ' = 1 WHERE ' + @CreateTimestampColumnName + ' IS NULL')
		
		-- Create an index on the CreateTimestamp column for better sync performance
		IF NOT EXISTS(SELECT * FROM sys.indexes WHERE [object_id]= '' + object_id(@TableName) + '' AND [name] = '' + 'IX_' + @TableName + '_' + @CreateTimestampColumnName + '')
			BEGIN
				EXEC ('CREATE NONCLUSTERED INDEX IX_' + @TableName + '_' + @CreateTimestampColumnName + ' ON dbo.' + @TableName + '(' + @CreateTimestampColumnName + ')');
			END
			
		-- ============================================================
		-- Check if the table has a tracking trigger and associated tombstone table.
		-- If it already has both, there is no need to get table keys in the next section.
		-- ============================================================
		SET @TombstoneTableName = @TableName + '_Tombstone';

		IF EXISTS (SELECT s.name, t.name FROM sys.tables t
						JOIN sys.schemas s ON t.schema_id = s.schema_id
						WHERE s.name = @SchemaName AND t.name = @TombstoneTableName)
		BEGIN
			PRINT @SchemaAndTableName + N': already has the tombstones table ' + @TombstoneTableName + '.';
			SET @HasTombstoneTable = 1;
			-- See if the tombstone table has a DeleteTimestamp column.  If it doesn't, then it needs to be upgraded
			IF NOT EXISTS (SELECT [name] FROM sys.columns 
							WHERE [name] = 'DeleteTimestamp'
							AND [object_id] = Object_ID(@TombstoneTableName))
				BEGIN 
					SET @CreateDeleteTimestampColumn = 1;
				END
			
		END;

		SET @DeleteTriggerName = 'trgdel_' + @TableName;
		IF EXISTS (SELECT [name] FROM sys.triggers
					   WHERE [name] = @DeleteTriggerName 
					   AND [parent_id] = @ObjectId)
		BEGIN
			PRINT 'Dropping trigger: ' +  @DeleteTriggerName;
			EXEC('DROP TRIGGER ' + @DeleteTriggerName)
		END;

		SET @InsertTriggerName = 'trgins_' + @TableName;
		IF EXISTS (SELECT [name] FROM sys.triggers
					   WHERE [name] = @InsertTriggerName 
					   AND [parent_id] = @ObjectId)
		BEGIN
			PRINT @SchemaAndTableName + N': already has the trigger ' + @InsertTriggerName + '.';
			SET @HasInsertTrigger = 1;
		END;
		
		SET @UpdateTriggerName = 'trgupd_' + @TableName;
		IF EXISTS (SELECT [name] FROM sys.triggers
					   WHERE [name] = @UpdateTriggerName 
					   AND [parent_id] = @ObjectId)
		BEGIN
			PRINT @SchemaAndTableName + N': already has the trigger ' + @UpdateTriggerName + '.';
			SET @HasUpdateTrigger = 1;
		END;

		-- ============================================================
		-- If the table is lacking a trigger or associated tombstones table, create them.
		-- ============================================================
		IF @HasTombstoneTable = 0 OR @HasInsertTrigger = 0 OR @HasUpdateTrigger = 0 OR @CreateDeleteTimestampColumn = 1
		BEGIN

			-- Make sure #AppTableKeys is empty.
			DELETE #AppTableKeys;

			-- Call sp_GetPrimaryKeysForTable to get the table's primary key, which is 
			-- required for the tombstone table and trigger.
			SET @GetKeysString = N'sp_GetPrimaryKeysForTable @table_name = ' + @TableName + ', @table_owner = ' + @SchemaName;
			INSERT INTO #AppTableKeys
			EXEC(@GetKeysString);

			SET @KeyDefinitionString = '';
			SET @ColumnDefinitionString = '';
			SET @CurrentKeyRowCount = 1;
			SELECT @MaxKeyRowCount = MAX(KeyColumnSequence) FROM #AppTableKeys;

			WHILE @CurrentKeyRowCount <= @MaxKeyRowCount
			BEGIN
				-- The following assignment to @ColumnDefinitionString works b/c all keys in the app tables are of type int.
				SELECT @KeyColumnName = KeyColumnName, @KeyColumnDataType = DataType, @KeyColumnLength = Length, @KeyColumnScale = Scale, @KeyColumnNumericPrecision = NumericPrecision,
					   @KeyDefinitionString = @KeyDefinitionString + '[' + KeyColumnName + '], '
				FROM #AppTableKeys 
				WHERE KeyColumnSequence = @CurrentKeyRowCount;

				if @KeyColumnDataType = 'nvarchar'
					SET @ColumnDefinitionString = @ColumnDefinitionString + '[' + @KeyColumnName + '] ' + @KeyColumnDataType + '(' + CAST(@KeyColumnLength AS NVARCHAR) + ') NOT NULL, '
				else
					if @KeyColumnDataType = 'decimal'
						SET @ColumnDefinitionString = @ColumnDefinitionString + '[' + @KeyColumnName + '] ' + @KeyColumnDataType + '(' + CAST(@KeyColumnScale AS NVARCHAR) + ', ' + CAST(@KeyColumnNumericPrecision AS NVARCHAR) + ') NOT NULL, '
					else
						SET @ColumnDefinitionString = @ColumnDefinitionString + '[' + @KeyColumnName + '] ' + @KeyColumnDataType + ' NOT NULL, '
					
				SET @CurrentKeyRowCount = @CurrentKeyRowCount + 1;
			END

			--  @KeyArray needs a final comma, which will be stripped from @KeyDefinitionString
			SET @KeyArray1 = @KeyDefinitionString;
			SET @KeyArray2 = @KeyDefinitionString;
			SET @KeyArray3 = @KeyDefinitionString;

			IF LEN(@KeyDefinitionString) > 0
			BEGIN
				-- Remove the final comma from @KeyDefinitionString
				SET @KeyDefinitionString = SUBSTRING(@KeyDefinitionString,1,LEN(@KeyDefinitionString)-1);
				
				-- ============================================================
				-- Add a tombstones table if the table doesn't have one.
				-- ============================================================
				IF @HasTombstoneTable = 0
				BEGIN
					SET @CreateTombstoneTableString = 'CREATE TABLE ' + @SchemaName + '.' + @TombstoneTableName + ' (' + @ColumnDefinitionString + 'DeleteDate datetime NOT NULL DEFAULT GetUTCDate(), DeleteOriginatorId int NOT NULL DEFAULT ' + CAST(@SyncID AS NVARCHAR) + ', DeleteTimestamp bigint NOT NULL DEFAULT CAST(@@DBTS AS BIGINT)+1, UpdateTimestamp timestamp NOT NULL)';
					SET @CreateTombstoneTableString = @CreateTombstoneTableString + ' ALTER TABLE ' + @SchemaName + '.' + @TombstoneTableName + ' ADD PRIMARY KEY CLUSTERED(' + @KeyDefinitionString + ')';
					EXEC(@CreateTombstoneTableString);
					PRINT @SchemaAndTableName + N': created tombstones table ' + @TombstoneTableName + '.';
					
					-- Create an index on the DeleteTimestamp column for better sync performance
					EXEC ('CREATE NONCLUSTERED INDEX IX_' + @TombstoneTableName + '_DeleteTimestamp ON dbo.' + @TombstoneTableName + '(DeleteTimestamp)');
					-- Create an index on the DeleteDate column for better sync performance
					EXEC ('CREATE NONCLUSTERED INDEX IX_' + @TombstoneTableName + '_DeleteDate ON dbo.' + @TombstoneTableName + '(DeleteDate)');
					-- Create an index on the DeleteDate column for better sync performance
					EXEC ('CREATE NONCLUSTERED INDEX IX_' + @TombstoneTableName + '_DeleteOriginatorId ON dbo.' + @TombstoneTableName + '(DeleteOriginatorId)');
				END;
				
				IF @CreateDeleteTimestampColumn = 1
				BEGIN
					EXEC('ALTER TABLE ' + @SchemaName + '.' + @TombstoneTableName + ' ADD DeleteTimestamp bigint NOT NULL DEFAULT CAST(@@DBTS AS BIGINT)+1');
					EXEC('ALTER TABLE ' + @SchemaName + '.' + @TombstoneTableName + ' ADD UpdateTimestamp timestamp NOT NULL');
					EXEC ('CREATE NONCLUSTERED INDEX IX_' + @TombstoneTableName + '_DeleteTimestamp ON dbo.' + @TombstoneTableName + '(DeleteTimestamp)');
				END;
				
				-- ============================================================
				-- Add a delete tracking trigger if the table doesn't have one.
				-- ============================================================
				SET @CreateDeleteTriggerString = 'CREATE TRIGGER ' + @SchemaName + '.' + @DeleteTriggerName + ' ON ' + @SchemaAndTableName + ' AFTER DELETE AS BEGIN SET NOCOUNT ON; '
				SET @CreateDeleteTriggerString = @CreateDeleteTriggerString + 'DELETE FROM ' + @TombstoneTableName + ' WHERE '

				-- Go through the array of keys and create an IN...SELECT statement for each key column. 
				-- This part of the trigger ensures that the tombstone table cannot contain multiple rows
				-- for the same row in the base table.
				WHILE PATINDEX('%,%' , @KeyArray1) <> 0 
				BEGIN
				  SET @KeyArraySeparatorPosition =  PATINDEX('%,%' , @KeyArray1)
				  SET @KeyArrayValue = LEFT(@KeyArray1, @KeyArraySeparatorPosition - 1)
				  SET @CreateDeleteTriggerString = @CreateDeleteTriggerString + @KeyArrayValue + ' IN (SELECT ' + @KeyArrayValue + ' FROM deleted) AND '
				  SET @KeyArray1 = STUFF(@KeyArray1, 1, @KeyArraySeparatorPosition, '')
				END

				-- Remove the final 'AND' from @CreateDeleteTriggerString
				SET @CreateDeleteTriggerString = SUBSTRING(@CreateDeleteTriggerString,1,LEN(@CreateDeleteTriggerString)-3)
				SET @CreateDeleteTriggerString = @CreateDeleteTriggerString + ' INSERT INTO ' + @TombstoneTableName + ' (' + @KeyDefinitionString + ', DeleteDate, DeleteOriginatorId, DeleteTimestamp) SELECT ' + @KeyDefinitionString + ', GetUTCDate() AS DeleteDate, ' + CAST(@SyncID AS NVARCHAR) + ' AS DeleteOriginatorId, CAST(@@DBTS AS BIGINT)+1 AS DeleteTimestamp FROM deleted; END;'
				EXEC(@CreateDeleteTriggerString);
				PRINT @SchemaAndTableName + N': created trigger ' + @DeleteTriggerName + '.';
			
				-- ============================================================
				-- Add an update tracking trigger if the table doesn't have one.
				-- ============================================================
				IF @HasUpdateTrigger = 0
				BEGIN
					SET @CreateUpdateTriggerString = 'CREATE TRIGGER ' + @SchemaName + '.' + @UpdateTriggerName + ' ON ' + @SchemaAndTableName + ' FOR UPDATE AS BEGIN SET NOCOUNT ON; '
					SET @CreateUpdateTriggerString = @CreateUpdateTriggerString + 'IF UPDATE(' + @UpdateOriginatorIdColumnName + ') AND UPDATE(' + @ModifiedDateColumnName + ') RETURN; '
					SET @CreateUpdateTriggerString = @CreateUpdateTriggerString + 'IF NOT UPDATE(' + @UpdateOriginatorIdColumnName + ') UPDATE ' + @SchemaAndTableName + ' SET ' + @UpdateOriginatorIdColumnName + '=' + CAST(@SyncID AS NVARCHAR) + ', ' + @ModifiedDateColumnName + ' = GETUTCDATE() WHERE '
					SET @CreateUpdateTriggerString2 = 'ELSE UPDATE ' + @SchemaAndTableName + ' SET ' + @ModifiedDateColumnName + ' = GETUTCDATE() WHERE '

					-- Go through the array of keys and create an IN...SELECT statement for each key column. 
					-- This part of the trigger ensures that the updated row's update timestamp is automatically set
					SET @TriggerKeyString = ''
					WHILE PATINDEX('%,%' , @KeyArray3) <> 0 
					BEGIN
					  SET @KeyArraySeparatorPosition =  PATINDEX('%,%' , @KeyArray3)
					  SET @KeyArrayValue = LEFT(@KeyArray3, @KeyArraySeparatorPosition - 1)
					  SET @TriggerKeyString = @TriggerKeyString + @KeyArrayValue + ' IN (SELECT ' + @KeyArrayValue + ' FROM inserted) AND '
					  SET @KeyArray3 = STUFF(@KeyArray3, 1, @KeyArraySeparatorPosition, '')
					END

					-- Remove the final 'AND' from @CreateUpdateTriggerString
					SET @TriggerKeyString = SUBSTRING(@TriggerKeyString,1,LEN(@TriggerKeyString)-3)
					SET @CreateUpdateTriggerString = @CreateUpdateTriggerString + @TriggerKeyString + ' ' + @CreateUpdateTriggerString2 + @TriggerKeyString + ' END;'
					EXEC(@CreateUpdateTriggerString);
					PRINT @SchemaAndTableName + N': created trigger ' + @UpdateTriggerName + '.';
				END;
				
			END
		END;

	SET @HasInsertTrigger = 0;
	SET @HasUpdateTrigger = 0;
	SET @HasTombstoneTable = 0;
	SET @CreateDeleteTimestampColumn = 0;
	
	PRINT '';

	END;

	SET @CurrentTableRowCount = @CurrentTableRowCount + 1;

END;

---------------------------------------------------------------------------------------------
-- Clean up temp tables and exit with success.
---------------------------------------------------------------------------------------------
DROP TABLE #AppTable;
DROP TABLE #AppTableKeys;
EXEC('sp_msforeachtable ''ALTER TABLE ? ENABLE TRIGGER ALL ''');

PRINT N'Tracking configuration added successfully.';
GO
/****** Object:  StoredProcedure [dbo].[sp_Disable_Triggers]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_Disable_Triggers]  @disable BIT = 1 AS      DECLARE         @sql VARCHAR(500),         @tableName VARCHAR(128),         @triggerName VARCHAR(128),         @tableSchema VARCHAR(128)      -- List of all triggers and tables that exist on them     DECLARE triggerCursor CURSOR         FOR     SELECT         so_tr.name AS TriggerName,         so_tbl.name AS TableName,         t.TABLE_SCHEMA AS TableSchema     FROM         sysobjects so_tr     INNER JOIN sysobjects so_tbl ON so_tr.parent_obj = so_tbl.id     INNER JOIN INFORMATION_SCHEMA.TABLES t      ON          t.TABLE_NAME = so_tbl.name     WHERE         so_tr.type = 'TR' and so_tr.name NOT LIKE 'msmerge%'     ORDER BY         so_tbl.name ASC,         so_tr.name ASC      OPEN triggerCursor      FETCH NEXT FROM triggerCursor      INTO @triggerName, @tableName, @tableSchema      WHILE ( @@FETCH_STATUS = 0 )         BEGIN             IF @disable = 1                  SET @sql = 'DISABLE TRIGGER ['                      + @triggerName + '] ON '                      + @tableSchema + '.[' + @tableName + ']'             ELSE                  SET @sql = 'ENABLE TRIGGER ['                      + @triggerName + '] ON '                      + @tableSchema + '.[' + @tableName + ']'              PRINT 'Executing Statement - ' + @sql             EXECUTE ( @sql )             FETCH NEXT FROM triggerCursor              INTO @triggerName, @tableName,  @tableSchema         END      CLOSE triggerCursor     DEALLOCATE triggerCursor  
GO
/****** Object:  StoredProcedure [dbo].[sp_GetPrimaryKeysForTable]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[sp_GetPrimaryKeysForTable]
	@table_name nvarchar(128),
	@table_owner nvarchar(128) = null
AS

declare @full_table_name nvarchar(500)
if (@table_owner is null)
	set @full_table_name = quotename(@table_name)
else
	set @full_table_name = quotename(@table_owner) + '.' + quotename(@table_name)

declare @table_id int
select @table_id = object_id(@full_table_name)


SELECT	TableQualifier = convert(sysname,db_name()),
        TableOwner = convert(sysname,schema_name(o.schema_id)),
        TableName = convert(sysname,o.name),
		c.name AS [ColumnName],
		t.name AS [DataType],
		CAST(CASE WHEN baset.name IN (N'nchar', N'nvarchar') AND c.max_length <> -1 THEN c.max_length/2 ELSE c.max_length END AS int) AS [Length],
		CAST(c.precision AS int) AS [NumericPrecision],
		CAST(c.scale AS int) AS [Scale],
		KeySequence = convert (smallint,
            case
                when c.name = index_col(@full_table_name, i.index_id,  1) then 1
                when c.name = index_col(@full_table_name, i.index_id,  2) then 2
                when c.name = index_col(@full_table_name, i.index_id,  3) then 3
                when c.name = index_col(@full_table_name, i.index_id,  4) then 4
                when c.name = index_col(@full_table_name, i.index_id,  5) then 5
                when c.name = index_col(@full_table_name, i.index_id,  6) then 6
                when c.name = index_col(@full_table_name, i.index_id,  7) then 7
                when c.name = index_col(@full_table_name, i.index_id,  8) then 8
                when c.name = index_col(@full_table_name, i.index_id,  9) then 9
                when c.name = index_col(@full_table_name, i.index_id, 10) then 10
                when c.name = index_col(@full_table_name, i.index_id, 11) then 11
                when c.name = index_col(@full_table_name, i.index_id, 12) then 12
                when c.name = index_col(@full_table_name, i.index_id, 13) then 13
                when c.name = index_col(@full_table_name, i.index_id, 14) then 14
                when c.name = index_col(@full_table_name, i.index_id, 15) then 15
                when c.name = index_col(@full_table_name, i.index_id, 16) then 16
            end),
		KeyName = convert(sysname,i.name)
FROM
        sys.indexes i,
        sys.all_columns c,
        sys.all_objects o,
		sys.types t,
		sys.types baset 		
where
		baset.user_type_id = c.system_type_id and
		baset.user_type_id = baset.system_type_id and
		t.user_type_id = c.user_type_id and
        o.object_id = @table_id and
        o.object_id = c.object_id and
        o.object_id = i.object_id and
        i.is_primary_key = 1 and
        (c.name = index_col (@full_table_name, i.index_id,  1) or
         c.name = index_col (@full_table_name, i.index_id,  2) or
         c.name = index_col (@full_table_name, i.index_id,  3) or
         c.name = index_col (@full_table_name, i.index_id,  4) or
         c.name = index_col (@full_table_name, i.index_id,  5) or
         c.name = index_col (@full_table_name, i.index_id,  6) or
         c.name = index_col (@full_table_name, i.index_id,  7) or
         c.name = index_col (@full_table_name, i.index_id,  8) or
         c.name = index_col (@full_table_name, i.index_id,  9) or
         c.name = index_col (@full_table_name, i.index_id, 10) or
         c.name = index_col (@full_table_name, i.index_id, 11) or
         c.name = index_col (@full_table_name, i.index_id, 12) or
         c.name = index_col (@full_table_name, i.index_id, 13) or
         c.name = index_col (@full_table_name, i.index_id, 14) or
         c.name = index_col (@full_table_name, i.index_id, 15) or
         c.name = index_col (@full_table_name, i.index_id, 16))
    order by 1, 2, 3, 8
GO
/****** Object:  StoredProcedure [dbo].[sp_IsValidTableForTracking]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[sp_IsValidTableForTracking]
	@TableName nvarchar(128),
	@IsValid bit OUTPUT
as
	if PATINDEX('%TOMBSTONE%', UPPER(@TableName)) <> 0
	begin
		set @IsValid = 0
		return 0
	end
	
	if PATINDEX('%ASPNET%', UPPER(@TableName)) <> 0
	begin
		set @IsValid = 0
		return 0
	end
		
	if @TableName = 'AccountingInterfaceSettings' or
		@TableName = 'AR_Accounting_Transaction' or
		@TableName = 'Customer_Accounting_Transaction' or
		@TableName = 'Enterprise_Activations' or
		@TableName = 'Executes' or
		@TableName = 'Executes_Destinations' or
		@TableName = 'Executes_LastHandled' or
		@TableName = 'GreenBerrysWeeklyReport' or
		@TableName = 'Inventory_Accounting_Transaction' or
		@TableName = 'Inventory_Taking' or
		@TableName = 'Invoice_AccountingExport' or
		@TableName = 'Invoice_Journal_Accounting_Transaction' or
		@TableName = 'Item_Accounting_Transaction' or
		@TableName = 'Measurements' or
		@TableName = 'Mobile_Discount' or
		@TableName = 'Mobile_Donations' or
		@TableName = 'Mobile_Inventory' or
		@TableName = 'Mobile_Inventory_SKUS' or
		@TableName = 'Mobile_PO_Details' or
		@TableName = 'Mobile_PO_Summary' or
		@TableName = 'Modifier_Groups' or
		@TableName = 'Modifier_Groups_Details' or
		@TableName = 'Modifier_Groups_SubMods' or
		@TableName = 'Payout_Accounting_Transaction' or
		@TableName = 'Pending_Orders' or
		@TableName = 'Pending_Orders_ItemRoutes' or
		@TableName = 'Pending_Orders_Items' or
		@TableName = 'PO_Summary_Accounting_Transaction' or
		@TableName = 'QB_Sales_Pass_Files' or
		@TableName = 'Setup_Corp' or
		@TableName = 'Timesheet_Accounting_Transaction' or
		@TableName = 'Vendor_Accounting_Transaction' or
		@TableName = 'Sync_ClientIdentification'
				
		set @IsValid = 0
	else
		set @IsValid = -1
GO
/****** Object:  StoredProcedure [dbo].[sp_RemoveTracking]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[sp_RemoveTracking]

AS

DECLARE @CurrentTableRowCount int;
DECLARE @MaxTableRowCount int;

DECLARE @SchemaName nvarchar(128);

DECLARE @ErrorNum int;

IF OBJECT_ID('tempdb..#AppTable') IS NOT NULL
BEGIN
   DROP TABLE #AppTable
END

CREATE TABLE #AppTable (AppTableID INT, SchemaName NVARCHAR(128)
                      , TableName NVARCHAR(128), EnableTracking BIT);

DECLARE @tableName NVARCHAR( 128 )
DECLARE @lastTableName NVARCHAR( 128 )
DECLARE @appTableRowCounter INT
DECLARE @ValidTable bit
SET @appTableRowCounter = 0
SET @lastTableName = ''
SET @ValidTable = 0

SELECT @tableName = MIN( [name] ) FROM sys.tables GROUP BY [name] ORDER BY [name] DESC

WHILE @tableName <> @lastTableName
BEGIN
    SET @appTableRowCounter = @appTableRowCounter + 1
    exec sp_IsValidTableForTracking @TableName= @tableName, @IsValid=@ValidTable OUTPUT
    
	IF @ValidTable = 1
		INSERT INTO #AppTable VALUES (@appTableRowCounter,N'dbo',@tableName,1);
	SET @lastTableName = @tableName
    SELECT @tableName = MIN( [name] ) FROM sys.tables WHERE [name] > @tableName GROUP BY [name] ORDER BY [name] DESC
END

DECLARE @SchemaAndTableName nvarchar(256);
DECLARE @ObjectId int;
DECLARE @EnableTracking bit;

DECLARE @TombstoneTableName nvarchar(128);
DECLARE @DeleteTriggerName nvarchar(128);
DECLARE @InsertTriggerName nvarchar(128);
DECLARE @UpdateTriggerName nvarchar(128);

-- The following variables were declared in the previous section of the script
SET @SchemaName = '';
SET @TableName = '';
SET @CurrentTableRowCount = 1;
SELECT @MaxTableRowCount = MAX(AppTableID) FROM #AppTable;

WHILE @CurrentTableRowCount <= @MaxTableRowCount
BEGIN
	SELECT @SchemaName = SchemaName, @TableName = TableName, @EnableTracking = EnableTracking 
		 , @SchemaAndTableName = @SchemaName + N'.' + @TableName
	FROM #AppTable
	WHERE AppTableID = @CurrentTableRowCount;
	
	IF @EnableTracking = 1
	BEGIN
		SET @ObjectId = OBJECT_ID(@SchemaAndTableName)
		
		SET @DeleteTriggerName = 'trgdel_' + @TableName;
		IF EXISTS (SELECT [name] FROM sys.triggers
					   WHERE [name] = @DeleteTriggerName 
					   AND [parent_id] = @ObjectId)
		BEGIN
			EXEC('DROP TRIGGER ' + @DeleteTriggerName)
			PRINT 'Dropped trigger: ' + @DeleteTriggerName;
		END;

		SET @InsertTriggerName = 'trgins_' + @TableName;
		IF EXISTS (SELECT [name] FROM sys.triggers
					   WHERE [name] = @InsertTriggerName 
					   AND [parent_id] = @ObjectId)
		BEGIN
			EXEC('DROP TRIGGER ' + @InsertTriggerName)
			PRINT 'Dropped trigger: ' + @InsertTriggerName;
		END;
		
		SET @UpdateTriggerName = 'trgupd_' + @TableName;
		IF EXISTS (SELECT [name] FROM sys.triggers
					   WHERE [name] = @UpdateTriggerName 
					   AND [parent_id] = @ObjectId)
		BEGIN
			EXEC('DROP TRIGGER ' + @UpdateTriggerName)
			PRINT 'Dropped trigger: ' + @UpdateTriggerName;
		END;

		-- Check if the table has a tracking trigger and associated tombstone table.
		SET @TombstoneTableName = @TableName + '_Tombstone';

		IF EXISTS (SELECT s.name, t.name FROM sys.tables t
						JOIN sys.schemas s ON t.schema_id = s.schema_id
						WHERE s.name = @SchemaName AND t.name = @TombstoneTableName)
		BEGIN
			EXEC('DROP TABLE ' + @TombstoneTableName)
			PRINT 'Dropped table: ' + @TombstoneTableName;
		END;
	
	PRINT '';

	END;

	SET @CurrentTableRowCount = @CurrentTableRowCount + 1;

END;

---------------------------------------------------------------------------------------------
-- Clean up temp tables and exit with success.
---------------------------------------------------------------------------------------------
DROP TABLE #AppTable;
PRINT N'Tracking configuration removed successfully.';
GO
/****** Object:  StoredProcedure [dbo].[storeproduction]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[storeproduction](@presentdate1 datetime,@presentdate2 datetime,@lastdate1 datetime,@lastdate2 datetime) AS SELECT     LabelProduction.StoreID, LabelProduction.StoreID + '  ' + Setup.Store_Description AS cur, Categories.Description, SUM(LabelProduction.Quantity * LabelProduction.Price) AS total, 'TY' AS Type, Setup.Store_Description FROM         LabelProduction INNER JOIN  Inventory INNER JOIN  Departments RIGHT OUTER JOIN  Categories LEFT OUTER JOIN Setup ON Setup.Store_ID = Categories.Store_ID ON Departments.SubType = Categories.Cat_ID AND Departments.Store_ID = Categories.Store_ID ON Departments.Dept_ID = Inventory.Dept_ID AND Departments.Store_ID = Inventory.Store_ID ON LabelProduction.ItemNumber = Inventory.ItemNum AND LabelProduction.StoreID = Inventory.Store_ID AND LabelProduction.PrintDate BETWEEN @presentDate1 AND @presentDate2 GROUP BY LabelProduction.StoreID, Categories.Description, Setup.Store_Description UNION  SELECT     LabelProduction.StoreID, LabelProduction.StoreID + '  ' + Setup.Store_Description AS cur, Categories.Description, SUM(LabelProduction.Quantity * LabelProduction.Price) AS total, 'LY' AS Type, Setup.Store_Description FROM         LabelProduction INNER JOIN  Inventory INNER JOIN Departments RIGHT OUTER JOIN  Categories LEFT OUTER JOIN Setup ON Setup.Store_ID = Categories.Store_ID ON Departments.SubType = Categories.Cat_ID AND Departments.Store_ID = Categories.Store_ID ON Departments.Dept_ID = Inventory.Dept_ID AND Departments.Store_ID = Inventory.Store_ID ON LabelProduction.ItemNumber = Inventory.ItemNum AND LabelProduction.StoreID = Inventory.Store_ID AND LabelProduction.PrintDate BETWEEN @lastDate1 AND @lastDate2 GROUP BY LabelProduction.StoreID, Categories.Description, Setup.Store_Description
GO
/****** Object:  StoredProcedure [dbo].[update_reporting_tables]    Script Date: 1/30/2026 5:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
create procedure [dbo].[update_reporting_tables]
    @storeId varchar(10)
as
	set nocount on

	-- get invoice totals
	select 
		@storeId as store_id,
		convert(varchar(4),DatePart(year,[datetime])) + '-' 
			+ REPLACE(STR(DATEPART(MONTH,[datetime]),2),' ','0') + '-'
			+ REPLACE(STR(DATEPART(day,[datetime]),2),' ','0') 			
			as date_key,
		sum(total_price)as total_price,
		sum(total_cost) as total_cost,
		convert(decimal(12,2),0) as labor_cost,
		convert(decimal(12,2),0) as labor_minutes
	 into #invoice_totals			
	 from Invoice_Totals where store_id = @storeId
		group by DatePart(year,[datetime]), DATEPART(month,[datetime]), DATEPART(day,[datetime])

	-- add in labor totals
	select
			convert(varchar(4),DatePart(year,[StartDateTime])) + '-' 
			+ REPLACE(STR(DATEPART(MONTH,[StartDateTime]),2),' ','0') + '-'
			+ REPLACE(STR(DATEPART(day,[StartDateTime]),2),' ','0') 			
			as date_key,
			sum(numMinutes) as NumMinutes,
			sum(wages) as Wages
	into #time_clock
	from Time_Clock	
	group by DatePart(year,[StartDateTime]), DATEPART(month,[StartDateTime]), DATEPART(day,[StartDateTime])

	
	update #invoice_totals
		set labor_cost = t.Wages,
			labor_minutes = t.NumMinutes
		from #invoice_totals i, #time_clock t
		where i.date_key = t.date_key

	select * from #invoice_totals

	set nocount off
GO
USE [master]
GO
ALTER DATABASE [cresql] SET  READ_WRITE 
GO
