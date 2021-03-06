

-- Create cursor to step through all builder module sets which don't include the wolfsonian process module
DECLARE folder_cursor CURSOR FOR   
SELECT ModuleSetID
  FROM SobekCM_Builder_Module_Set S, SobekCM_Builder_Module_Type T
  where T.ModuleTypeID=S.ModuleTypeID
    and T.TypeAbbrev = 'FOLD'
	and not exists ( select 1 from SobekCM_Builder_Module M where M.ModuleSetID=S.ModuleSetID and M.Class='WolfsonianBuilderModule.WolfsonianObjectProcessorModule' );

-- Variable used by cursor for each module set id to work on
declare @moduleSetId int;

-- Open cursor and fetch first module set id
OPEN folder_cursor;  
FETCH NEXT FROM folder_cursor INTO @moduleSetId;

-- Step through them all
WHILE @@FETCH_STATUS = 0  
BEGIN  

	-- Move all the modules past the first up one in order
	update SobekCM_Builder_Module
	set [Order] = [Order] + 1
	where ModuleSetID=@moduleSetId
	  and [Order] > 1;

	-- Now, add this as order 2 in that module set		
	insert into SobekCM_Builder_Module ( ModuleSetID, ModuleDesc, [Assembly], Class, [Enabled], [Order], Argument1 )
	values ( @moduleSetId, 'Wolfsonian Library processing module', 'WolfsonianBuilderModule.dll', 'WolfsonianBuilderModule.WolfsonianObjectProcessorModule', 'true', 2, 'LIBRARY' );

	-- Get the next module set
	FETCH NEXT FROM folder_cursor INTO @moduleSetId;

END;

CLOSE folder_cursor;  
DEALLOCATE folder_cursor;  
GO

CREATE PROCEDURE [dbo].[Wolfsonian_Find_BibID_From_Accession_Number]
	@AccessionNumber varchar(20),
	@BibID varchar(10) output,
	@VID varchar(5) output,
	@Message varchar(200) output
AS
BEGIN

	-- Default empty bibid 
	set @BibID='';
	set @VID='00001';

	-- Try to match from the item search table
	declare @itemMatchCount int;
	set @itemMatchCount = ( select count(*) from SobekCM_Metadata_Basic_Search_Table where Accession_Number=@AccessionNumber );
	if ( @itemMatchCount > 0 )
	begin
		-- If more than one match, that is a problem
		if ( @itemMatchCount > 1 ) 
		begin
			set @Message = 'ERROR: More than one item matches this accession number (' + cast(@AccessionNumber as varchar(200)) + ')!';
			return;
		end;

		-- Only one match, so return it
		set @BibID = ( select BibID from SobekCM_Metadata_Basic_Search_Table where Accession_Number=@AccessionNumber);
		set @VID = ( select VID from SobekCM_Metadata_Basic_Search_Table S, SobekCM_Item I where S.Accession_Number=@AccessionNumber and I.ItemID=S.ItemID);
		set @Message = 'Matched existing item by accession number';
		return;
	end;

	-- If no match there, try to match against the group external identifier portion
	declare @titleMatchCount int;
	set @titleMatchCount = ( select count(*) from SobekCM_Item_Group_External_Record where ExtRecordValue=@AccessionNumber and ExtRecordTypeID=6 );
	if ( @titleMatchCount > 0 )
	begin
		-- If more than one match, that is a problem
		if ( @titleMatchCount > 1 ) 
		begin
			set @Message = 'ERROR: More than one item group matches this accession number (' + cast(@AccessionNumber as varchar(200))  + ')!';
			return;
		end;

		-- Only one match, so return it
		set @BibID = ( select BibID 
		               from SobekCM_Item_Group_External_Record R, SobekCM_Item_Group G
					   where R.ExtRecordValue=@AccessionNumber 
					     and R.ExtRecordTypeID=6 
					     and R.GroupID = G.GroupID );
		set @Message = 'Matched existing item group by accession number';
		return;
	end;

	-- No match found
	set @Message = 'No match found';
END;
GO


CREATE PROCEDURE [dbo].[Wolfsonian_Library_Item_By_Identifier] 
	@Identifier varchar(20)
AS 
BEGIN
  select G.BibID, I.VID, I.Title, L.ItemID, S.MetadataValue
  from SobekCM_Metadata_Unique_Search_Table S, 
       SobekCM_Metadata_Unique_Link L, 
	   SobekCM_Item I, 
	   SobekCM_Item_Group G,
	   SobekCM_Item_Aggregation_Item_Link X,
	   SobekCM_Item_Aggregation A
  where S.MetadataID = L.MetadataID
    and S.MetadataTypeID=17
	and I.ItemID = L.ItemID
	and I.GroupID = G.GroupID
	and I.ItemID = X.ItemID
	and X.AggregationID = A.AggregationID
	and A.Code = 'library'
	and S.MetadataValue=@Identifier;
END;
GO

