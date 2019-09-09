unit uFileBuffer;

interface

uses

  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, Windows, Math,
  ADODB,  ActiveX, Generics.Collections, SyncObjs;

type
  TFileBufferList = class
  strict private
    FLock: TCriticalSection;
    FFileList: TObjectDictionary<string, TFileStream>;
  public
    constructor Create;
    destructor Destroy; override;
    function GetBuffer(AFileName:string):TFileStream;
  end;

implementation

{ TFileBuffer }

constructor TFileBufferList.Create;
begin
  FLock := TCriticalSection.Create;
  FFileList := TObjectDictionary<string, TFileStream>.Create([doOwnsValues],32);
end;

destructor TFileBufferList.Destroy;
var
  perStream: TFileStream;
begin
  FLock.Enter;
//  for perStream in FFileList.Values do
//    perStream.Free;
  FFileList.Free;
  FLock.Enter;
  FLock.Free;
  inherited;
end;

function TFileBufferList.GetBuffer(AFileName: string): TFileStream;
var
  key:string;
begin
  FLock.Enter;
  key := UpperCase(AFileName);
  if not FFileList.TryGetValue(key, result) then
  begin
    try
      result := TFileStream.Create(AFileName, fmCreate or fmOpenReadWrite or fmShareDenyNone);
      FFileList.Add(key, result);
    except
    end;
  end;
  FLock.Leave;
end;

end.
