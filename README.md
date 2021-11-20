# zMemTableExt
A class helper for ZMemTable  (a component in zeoslib)  
It contains some of the methods which I wrote for my personal project. Tested on Lazarus 2.0.12.

procedure SaveToBlob(BField: TBlobField);
//  Save zMemTable (memory stream) to a BlobField

procedure LoadFromBlob(BField: TBlobField);
//  Load zMemTable from a BlobField

procedure SaveToFile(Filename: TFilename; zip: Boolean =True);
//  Save zMemTable (memory stream) to a file
//       the stream are compressed using zstream if zip=True
//       (the compressed version of the output file starts 4 bytes of 0)

procedure LoadFromFile(Filename: TFilename);
//  Load zMemTable from a File. This method is able to recognise both the compressed and 
//    uncompressed file by checking the first 4 bytes of the file

procedure CopyStru(src: TDataSet; xcFields: TByteSet =[];
                                                 DeleteOldfields: Boolean=True);     
//  Copy the field definition of another dataset (src). 
//       xcfields - a set of byte which indicates the fieldDef that should not be copied
//       DeleteOldfield - To delete all the existing field of destination zMemTable     

procedure SetDecPlace(ftype: TFieldType; dec: byte);
// Set the displayformat of all ftype fields to #,### with specified decimal places (dec)
