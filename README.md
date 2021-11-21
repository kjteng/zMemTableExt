# zMemTableExt v1.02

A class helper for ZMemTable  (a component in zeoslib)  
It contains some of the methods which I wrote for my personal project. Tested on Lazarus 2.0.12.

procedure SaveToBlob(BField: TBlobField);
//  Save zMemTable (memory stream) to a BlobField

procedure LoadFromBlob(BField: TBlobField);
//  Load zMemTable from a BlobField

procedure SaveToFile(Filename: TFilename; zip: Boolean =True);
//  Save zMemTable (memory stream) to a file
//       the stream are compressed using zstream if zip=True

procedure LoadFromFile(Filename: TFilename);
//  Load zMemTable from a File. This method is able to recognise both the compressed and 
//    uncompressed file by checking the first 2 bytes of the zstream

procedure CopyStru(src: TDataSet; xcFields: array of integer; DeleteOldfields: Boolean=True);     
//  Copy the field definition of another dataset (src). 
//       xcfields - array of field number for which the fieldDef that should not be copied
//       DeleteOldfield - To delete all the existing field of destination zMemTable     

procedure CopyStru(src: TDataSet; DeleteOldfields: Boolean=True); overload
//  This is an overload method for the case where all fieldDef of the source dataset are to be copied

procedure SetDecPlace(ftype: TFieldType; dec: byte);
// Set the displayformat of all ftype fields to #,### with specified decimal places (dec)
