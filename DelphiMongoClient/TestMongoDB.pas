unit TestMongoDB;
{

  Delphi DUnit Test Case
  ----------------------
  This unit contains a skeleton test case class generated by the Test Case Wizard.
  Modify the generated code to correctly setup and call the methods from the unit 
  being tested.

}

interface

uses
  Classes, SysUtils, TestFramework, MongoDB, MongoBson;

type
  TestTMongo = class;
  // Test methods for class TMongo

  TMongoThread = class(TThread)
  private
    FErrorStr: String;
    FMongoTest: TestTMongo;
  protected
    procedure Execute; override;
  public
    constructor Create(AMongoTest: TestTMongo);
    property ErrorStr: String read FErrorStr write FErrorStr;
  end;

  TestMongoBase = class(TTestCase)
  protected
    FMongo: TMongo;
    function CreateMongo: TMongo; virtual;
    procedure SetUp; override;
    procedure TearDown; override;
  public
  end;

  TestTMongo = class(TestMongoBase)
  private
    test_db_created: Boolean;
    procedure Create_test_db;
    procedure Create_test_db_andCheckCollection(AExists: Boolean);
    procedure FindAndCheckBson(ID: Integer; const AValue: String);
    procedure InsertAndCheckBson(ID: Integer; const AValue: string);
    procedure RemoveTest_user;
  protected
    function GetExpectedPrimary: String; virtual;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestisConnected;
    procedure TestcheckConnection;
    procedure TestisMaster;
    procedure Testdisconnect;
    procedure Testreconnect;
    procedure TestgetErr;
    procedure TestsetTimeout;
    procedure TestgetTimeout;
    procedure TestgetPrimary;
    procedure TestgetSocket;
    procedure TestgetDatabases;
    procedure TestgetDatabaseCollections;
    procedure TestRename;
    procedure Testdrop;
    procedure TestdropDatabase;
    procedure TestInsert;
    procedure TestInsertArrayofBson;
    procedure TestUpdate;
    procedure Testremove;
    procedure TestfindOne;
    procedure TestfindOneWithSpecificFields;
    procedure Testfind;
    procedure TestCount;
    procedure TestCountWithQuery;
    procedure Testdistinct;
    procedure TestindexCreate;
    procedure TestindexCreateWithOptions;
    procedure TestindexCreateUsingBsonKey;
    procedure TestindexCreateUsingBsonKeyAndOptions;
    procedure TestaddUser;
    procedure TestaddUserWithDBParam;
    procedure Testauthenticate;
    procedure TestauthenticateWithSpecificDB;
    procedure TestauthenticateFail;
    procedure TestcommandWithBson;
    procedure TestcommandWithArgs;
    procedure TestgetLastErr;
    procedure TestgetPrevErr;
    procedure TestresetErr;
    procedure TestgetServerErr;
    procedure TestgetServerErrString;
    procedure TestFourThreads;
    procedure TestUseWriteConcern;
    procedure TestTryToUseUnfinishedWriteConcern;
  end;
  // Test methods for class TMongoReplset
  
  TestTMongoReplset = class(TestTMongo)
  protected
    FMongoReplset: TMongoReplset;
    function CreateMongo: TMongo; override;
    function GetExpectedPrimary: String; override;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestgetHost;
  end;
  // Test methods for class IMongoCursor
  
  TestIMongoCursor = class(TTestCase)
  private
    FIMongoCursor: IMongoCursor;
    FMongo: TMongoReplset;
    FMongoSecondary : TMongo;
  protected
    procedure DeleteSampleData;
    procedure SetupData;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestGetConn;
    procedure TestGetFields;
    procedure TestGetHandle;
    procedure TestGetLimit;
    procedure TestGetOptions;
    procedure TestGetQuery;
    procedure TestGetSkip;
    procedure TestGetSort;
    procedure TestNext;
    procedure TestSetFields;
    procedure TestSetLimit;
    procedure TestSetOptions;
    procedure TestSetQuery;
    procedure TestSetSkip;
    procedure TestSetSort;
    procedure TestValue;
  end;

var
  MongoStarted : Boolean;
  FSlaveStarted : Boolean;

procedure StartMongoDB(const AParams: String);

implementation

uses
  AppExec, CnvGenUtils, uFileManagement, Variants, Windows, FileCtrl
  {$IFDEF TAXPORT}, uScope, Forms, CnvStream, CnvFileUtils, JclDateTime {$ENDIF};

procedure StartMongoDB(const AParams: String);
{$IFDEF TAXPORT}
const
  MONGOD_NAME = 'mongod.exe';
  SRC_MONGOD = 'X:\CE\CnvFiles\DUnit\MongoDB\' + MONGOD_NAME;
var
  Scope : IScope;
  s : TCnvStream;
  f : TFileStream;
  TargetMongoDBPath, TargetMongoDFile : string;
  Files : TFileInfoList;
{$ENDIF}
begin
  {$IFDEF TAXPORT}
  Scope := NewScope;
  TargetMongoDBPath := ExtractFilePath(Application.ExeName) + '\MongoDB\';
  TargetMongoDFile := TargetMongoDBPath + MONGOD_NAME;
  Files := Scope.Add(TFileInfoList.Create);
  TCnvStream.GetStreamList(SRC_MONGOD, Files, False, True);
  if (Files.Count = 0) or (not FileExists(TargetMongoDFile)) or
     (Files.Infos[0].ModifyDate > FileTimeToDateTime(GetFileInfo(TargetMongoDFile).FindData.ftLastWriteTime)) then
    begin
      s := Scope.Add(TCnvStream.Create(SRC_MONGOD, cdbmRead));
      ForceDirectories(TargetMongoDBPath);
      f := Scope.Add(TFileStream.Create(TargetMongoDFile, fmCreate));
      f.CopyFrom(s, s.Size);
      FileSetDate(f.Handle, DateTimeToFileDate(s.CreateDate));
    end;
  Scope := nil;
  {$ENDIF}
  with TAppExec.Create(nil) do
    try
      ExeName := 'mongod.exe';
      ExePath := ExtractFilePath(ParamStr(0)) + '\MongoDB';
      ExeParams.CommaText := AParams;
      Execute;
    finally
      Free;
    end;
  Sleep(1000);
end;

procedure WaitForReplSetToBeReady;
var
  Ready : array [27018..27020] of Boolean;
  APort : Integer;
  OnePrimary : Boolean;
  buf : IBsonBuffer;
  b, res : IBson;
  v : Variant;
  i : integer;
begin
  APort := 27018;
  for i := low(Ready) to high(Ready) do
    Ready[i] := False;
  OnePrimary := False;
  repeat
    Sleep(200);
    with TMongo.Create(Format('127.0.0.1:%d', [APort])) do
      try
        buf := NewBsonBuffer;
        buf.Append(PAnsiChar('replSetGetStatus'), 1);
        b := buf.finish;
        res := command('admin', b);
        if res = nil then
          continue;
        v := res.Value('myState');
      finally
        Free;
      end;
    APort := APort + 1;
    if APort > 27020 then
      APort := 27018;
    if integer(v) in [1, 2] then
      Ready[APort] := True;
    if integer(v) = 1 then
      OnePrimary := True;
  until (not VarIsNull(v)) and Ready[27018] and Ready[27019] and Ready[27020] and OnePrimary;
end;

procedure StartReplSet;
var
  b : IBson;
  buf : IBsonBuffer;
begin
  if not FSlaveStarted then
    begin
      DeleteEntireDir(ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_1');
      ForceDirectories(ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_1');
      StartMongoDB('--dbpath ' + ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_1 --smallfiles --noprealloc --journalCommitInterval 5 --port 27018 --replSet foo');

      DeleteEntireDir(ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_2');
      ForceDirectories(ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_2');
      StartMongoDB('--dbpath ' + ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_2 --smallfiles --noprealloc --journalCommitInterval 5 --port 27019 --replSet foo');

      DeleteEntireDir(ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_3');
      ForceDirectories(ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_3');
      StartMongoDB('--dbpath ' + ExtractFilePath(ParamStr(0)) + '\MongoDataReplica_3 --smallfiles --noprealloc --journalCommitInterval 5 --port 27020 --replSet foo');

      with TMongo.Create('127.0.0.1:27018') do
        try
          buf := NewBsonBuffer;
          buf.startObject(PAnsiChar('replSetInitiate'));
            buf.AppendStr(PAnsiChar('_id'), PAnsiChar('foo'));
            buf.startArray(PAnsiChar('members'));
              buf.startObject('0');
                buf.Append(PAnsiChar('_id'), 0);
                buf.AppendStr(PAnsiChar('host'), PAnsiChar('127.0.0.1:27018'));
              buf.finishObject;
              buf.startObject('1');
                buf.Append(PAnsiChar('_id'), 1);
                buf.AppendStr(PAnsiChar('host'), PAnsiChar('127.0.0.1:27019'));
              buf.finishObject;
              buf.startObject('2');
                buf.Append(PAnsiChar('_id'), 2);
                buf.AppendStr(PAnsiChar('host'), PAnsiChar('127.0.0.1:27020'));
              buf.finishObject;
            buf.finishObject;
          buf.finishObject;
          b := buf.finish;
          command('admin', b);
        finally
          Free;
        end;
        WaitForReplSetToBeReady;
      FSlaveStarted := True;
    end;
end;

procedure ShutDownMongoDB;
begin
  while KillProcess('mongod.exe') do
    Sleep(200); // Need to sleep between calls to give time to first KillProcess call to succeed
end;

{ TestMongoBase }

function TestMongoBase.CreateMongo: TMongo;
begin
  Result := TMongo.Create;
end;

procedure TestMongoBase.SetUp;
begin
  inherited;
  if not MongoStarted then
    begin
      DeleteEntireDir(ExtractFilePath(ParamStr(0)) + '\MongoData');
      ForceDirectories(ExtractFilePath(ParamStr(0)) + '\MongoData');
      StartMongoDB('--dbpath ' + ExtractFilePath(ParamStr(0)) + '\MongoData --smallfiles --noprealloc --journalCommitInterval 5');
      MongoStarted := True;
    end;
  FMongo := CreateMongo;
end;

procedure TestMongoBase.TearDown;
begin
  FMongo.Free;
  FMongo := nil;
  inherited;
end;

{ TestTMongo }

procedure TestTMongo.Create_test_db;
var
  b : IBson;
begin
  if test_db_created then
    exit;
  b := BSON(['int_value', 0]);
  FMongo.Insert('test_db.test_col', b);
  //Sleep(50);
  test_db_created := True;
end;

procedure TestTMongo.Create_test_db_andCheckCollection(AExists: Boolean);
var
  Cols : TStringArray;
begin
  Create_test_db;
  Cols := FMongo.getDatabaseCollections('test_db');
  if AExists then
    begin
      CheckEquals(1, length(Cols), 'There should be at least one collection created');
      CheckEqualsString('test_db.test_col', Cols[0], 'First and only collection created should be named test_db.test_col');
    end
    else CheckEquals(0, length(Cols), 'There should be no collection created');
end;

procedure TestTMongo.FindAndCheckBson(ID: Integer; const AValue: String);
var
  q, b : IBson;
  ns : String;
begin
  ns := 'test_db.test_col';
  q := BSON(['int_fld', ID]);
  b := FMongo.findOne(ns, q);
  Check(b <> nil, 'Call to findOne should have returned a Bson object');
  CheckEqualsString(AValue, b.Value(PAnsiChar('val_fld')), 'Returned value should be equals to "' + AValue + '"');
end;

function TestTMongo.GetExpectedPrimary: String;
begin
  Result := '127.0.0.1:27017';
end;

procedure TestTMongo.InsertAndCheckBson(ID: Integer; const AValue: string);
var
  ReturnValue: Boolean;
  b: IBson;
  ns: string;
begin
  b := BSON(['int_fld', ID, 'val_fld', AValue]);
  ns := 'test_db.test_col';
  ReturnValue := FMongo.Insert(ns, b);
  Check(ReturnValue, 'call to Mongo.insert should return true');
  FindAndCheckBson(ID, AValue);
end;

procedure TestTMongo.RemoveTest_user;
var
  usr : IBson;
begin
  usr := BSON(['user', 'test_user']);
  Check(FMongo.remove('admin.system.users', usr), 'Call to Mongo.remove should return true removing user');
  Check(not FMongo.authenticate('test_user', 'test_password'), 'Call to Mongo.authenticate with removed user should return False');
end;

procedure TestTMongo.SetUp;
begin
  test_db_created := False;
  inherited;
end;

procedure TestTMongo.TearDown;
begin
  FMongo.drop('test_db.test_thread');
  FMongo.dropDatabase('test_db');
  inherited;
end;

procedure TestTMongo.TestisConnected;
var
  ReturnValue: Boolean;
begin
  ReturnValue := FMongo.isConnected;
  Check(ReturnValue, 'isConnected should be true');
end;

procedure TestTMongo.TestcheckConnection;
var
  ReturnValue: Boolean;
begin
  ReturnValue := FMongo.checkConnection;
  Check(ReturnValue, 'checkConnection should return true');
  FMongo.disconnect;
  ReturnValue := FMongo.checkConnection;
  Check(not ReturnValue, 'checkConnection should return false');
end;

procedure TestTMongo.TestisMaster;
var
  ReturnValue: Boolean;
begin
  ReturnValue := FMongo.isMaster;
  Check(ReturnValue, 'isMaster should be true');
end;

procedure TestTMongo.Testdisconnect;
begin
  Check(FMongo.isConnected, 'isConnected should be true before call to disconnect');
  FMongo.disconnect;
  Check(not FMongo.isConnected, 'isConnected should be false after disconnect');
end;

procedure TestTMongo.Testreconnect;
begin
  FMongo.disconnect;
  Check(not FMongo.isConnected, 'isConnected should be false after call to disconnect');
  FMongo.reconnect;
  Check(FMongo.isConnected, 'isConnected should be true after call to reconnect');
end;

procedure TestTMongo.TestgetErr;
var
  ReturnValue: Integer;
begin
  ReturnValue := FMongo.getErr;
  CheckEquals(0, ReturnValue, 'getErr should return zero'); 
end;

procedure TestTMongo.TestsetTimeout;
var
  ReturnValue: Boolean;
  millis: Integer;
begin
  millis := 1000;
  ReturnValue := FMongo.setTimeout(millis);
  Check(ReturnValue, 'setTimeout should return true');
end;

procedure TestTMongo.TestgetTimeout;
const
  millis = 1000;
var
  ReturnValue: Integer;
begin
  FMongo.setTimeout(millis);
  ReturnValue := FMongo.getTimeout;
  CheckEquals(millis, ReturnValue, 'getTimeout should return same value passed on previous call to setTimeout');
end;

procedure TestTMongo.TestgetPrimary;
var
  ReturnValue: string;
begin
  ReturnValue := FMongo.getPrimary;
  CheckEqualsString(GetExpectedPrimary, ReturnValue, 'Call to return primary should be ' + GetExpectedPrimary);
end;

procedure TestTMongo.TestgetSocket;
var
  ReturnValue: Integer;
begin
  ReturnValue := FMongo.getSocket;
  CheckNotEquals(0, ReturnValue, 'getSocket should return a non-zero value');
end;

procedure TestTMongo.TestgetDatabases;
var
  ReturnValue: TStringArray;
begin
  ReturnValue := FMongo.getDatabases;
  CheckEquals(0, length(ReturnValue), 'There should be no databases yet');
  Create_test_db;
  ReturnValue := FMongo.getDatabases;
  CheckNotEquals(0, length(ReturnValue), 'There should be at least one database create now');
end;

procedure TestTMongo.TestgetDatabaseCollections;
var
  ReturnValue: TStringArray;
  db: string;
begin
  db := 'test_db';
  ReturnValue := FMongo.getDatabaseCollections(db);
  CheckEquals(0, length(ReturnValue), 'There should be no collections on test_db database');
  Create_test_db;
  ReturnValue := FMongo.getDatabaseCollections(db);
  CheckEquals(1, length(ReturnValue), 'There should be one collection on test_db database');
end;

procedure TestTMongo.TestRename;
var
  ReturnValue: Boolean;
  to_ns: string;
  from_ns: string;
  Cols : TStringArray;
begin
  Create_test_db_andCheckCollection(True);
  from_ns := 'test_db.test_col';
  to_ns := 'test_db.test_col_renamed';
  ReturnValue := FMongo.Rename(from_ns, to_ns);
  Check(ReturnValue, 'Call to Mongo.Rename should return true');
  Cols := FMongo.getDatabaseCollections('test_db');
  CheckEquals(1, length(Cols), 'There should be at least one collection created');
  CheckEqualsString('test_db.test_col_renamed', Cols[0], 'First and only collection created should be named test_db.test_col_renamed');
end;

procedure TestTMongo.Testdrop;
var
  ReturnValue: Boolean;
  ns: string;
begin
  Create_test_db_andCheckCollection(True);
  ns := 'test_db.test_col';
  ReturnValue := FMongo.drop(ns);
  Check(ReturnValue, 'Call to Mongo.drop should return true');
  Create_test_db_andCheckCollection(False);
end;

procedure TestTMongo.TestdropDatabase;
var
  ReturnValue: Boolean;
  db: string;
  dbs : TStringArray;
begin
  Create_test_db_andCheckCollection(True);
  db := 'test_db';
  ReturnValue := FMongo.dropDatabase(db);
  Check(ReturnValue, 'Call to Mongo.dropDatabase should return True');
  dbs := FMongo.getDatabases;
  CheckEquals(0, length(dbs), 'After dropDatabase call there should be no databases created');
end;

procedure TestTMongo.TestInsert;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
end;

procedure TestTMongo.TestInsertArrayofBson;
var
  ReturnValue: Boolean;
  bs1, bs2: IBson;
  ns: string;
begin
  Create_test_db;
  bs1 := BSON(['int_fld', 1, 'val_fld', 'Value1']);
  bs2 := BSON(['int_fld', 2, 'val_fld', 'Value2']);
  ns := 'test_db.test_col';
  ReturnValue := FMongo.Insert(ns, [bs1, bs2]);
  Check(ReturnValue, 'Call to Mongo.Insert should return True');
  FindAndCheckBson(1, 'Value1');
  FindAndCheckBson(2, 'Value2');
end;

procedure TestTMongo.TestUpdate;
var
  ReturnValue: Boolean;
  objNew: IBson;
  criteria: IBson;
  ns: string;
begin
  Create_test_db;
  ns := 'test_db.test_col';
  InsertAndCheckBson(1, 'Value1');
  criteria := BSON(['int_fld', 1]);
  objNew := BSON(['int_fld', 5, 'val_fld', 'Value5']);
  ReturnValue := FMongo.Update(ns, criteria, objNew);
  Check(ReturnValue, 'call to Mongo.Update should return true');
  FindAndCheckBson(5, 'Value5');
end;

procedure TestTMongo.Testremove;
var
  ReturnValue: Boolean;
  b, criteria: IBson;
  ns: string;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  ns := 'test_db.test_col';
  criteria := BSON(['int_fld', 1]);
  ReturnValue := FMongo.remove(ns, criteria);
  Check(ReturnValue, 'call to Mongo.remove should return true');
  b := FMongo.findOne(ns, criteria);
  Check(b = nil, 'Call to findOne with non existing Bson object should return nil');
end;

procedure TestTMongo.TestfindOne;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1'); // This will call findOne internally
end;

procedure TestTMongo.TestfindOneWithSpecificFields;
var
  ReturnValue: IBson;
  fields: IBson;
  query: IBson;
  ns: string;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  ns := 'test_db.test_col';
  query := BSON(['int_fld', 1]);
  fields := BSON(['val_fld', 1]);
  ReturnValue := FMongo.findOne(ns, query, fields);
  CheckEqualsString('Value1', ReturnValue.Value(PAnsiChar('val_fld')), 'Call to Mongo.FindOne should have returned object with val_fld equals to "Value1"');
  Check(VarIsNull(ReturnValue.Value(PAnsiChar('int_fld'))), 'int_fld should not have been returned by call to IBson.Value');
end;

procedure TestTMongo.Testfind;
var
  ReturnValue: Boolean;
  Cursor: IMongoCursor;
  ns: string;
  n : Integer;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  InsertAndCheckBson(2, 'Value2');
  Cursor := NewMongoCursor;
  ns := 'test_db.test_col';
  ReturnValue := FMongo.find(ns, Cursor);
  Check(ReturnValue, 'Call to Mongo.Find should return True');
  n := 0;
  while Cursor.Next do
    inc(n);
  CheckEquals(3, n, 'Number of Bson objects returned by cursor should be equal to 3');
end;

procedure TestTMongo.TestCount;
var
  ReturnValue: Double;
  ns: string;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  ns := 'test_db.test_col';
  ReturnValue := FMongo.Count(ns);
  CheckEquals(2, ReturnValue, 'Value returned by Mongo.Count should be equals to 2');
end;

procedure TestTMongo.TestCountWithQuery;
var
  ReturnValue: Double;
  query: IBson;
  ns: string;
begin
  Create_test_db;
  InsertAndCheckBson(5, 'Value1');
  query := BSON(['int_fld', 5]);
  ns := 'test_db.test_col';
  ReturnValue := FMongo.Count(ns, query);
  CheckEquals(1, ReturnValue, 'Value returned by Mongo.Count should be equals to 1');
end;

procedure TestTMongo.Testdistinct;
var
  ReturnValue: IBson;
  i : IBsonIterator;
  key: string;
  ns: string;
  Arr : TIntegerArray;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  InsertAndCheckBson(1, 'Value1');
  InsertAndCheckBson(2, 'Value2');
  ns := 'test_db.test_col';
  CheckEquals(4, FMongo.Count(ns), 'Total number of objects stored on test_col should be equals to 4');
  key := 'int_fld';
  ReturnValue := FMongo.distinct(ns, key);
  Check(ReturnValue <> nil, 'Call to Mongo.distinct should have returned a value <> nil');
  i := ReturnValue.iterator;
  Arr := i.getIntegerArray;
  CheckEquals(2, length(Arr), 'Number of values returned by call to distinct should be equals to 2');
  CheckEquals(1, Arr[0], 'First value returned should be equals to 1');
  CheckEquals(2, Arr[1], 'Second value returned should be equals to 2');
end;

procedure TestTMongo.TestindexCreate;
var
  ReturnValue: IBson;
  key: string;
  ns: string;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  ns := 'test_db.test_col';
  key := 'int_fld';
  ReturnValue := FMongo.indexCreate(ns, key);
  Check(ReturnValue = nil, 'Call to Mongo.indexCreate should return nil if successful');
end;

procedure TestTMongo.TestindexCreateWithOptions;
var
  ReturnValue: IBson;
  options: Integer;
  key: string;
  ns: string;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  ns := 'test_db.test_col';
  key := 'int_fld';
  options := indexUnique;
  ReturnValue := FMongo.indexCreate(ns, key, options);
  Check(ReturnValue = nil, 'Call to Mongo.indexCreate should return nil if successful');
end;

procedure TestTMongo.TestindexCreateUsingBsonKey;
var
  ReturnValue: IBson;
  key: IBson;
  ns: string;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  ns := 'test_db.test_col';
  key := BSON(['int_fld', True]);
  ReturnValue := FMongo.indexCreate(ns, key);
  Check(ReturnValue = nil, 'Call to Mongo.indexCreate should return nil if successful');
end;

procedure TestTMongo.TestindexCreateUsingBsonKeyAndOptions;
var
  ReturnValue: IBson;
  options: Integer;
  key: IBson;
  ns: string;
begin
  Create_test_db;
  InsertAndCheckBson(1, 'Value1');
  ns := 'test_db.test_col';
  key := BSON(['int_fld', True]);
  options := indexUnique;
  ReturnValue := FMongo.indexCreate(ns, key, options);
  Check(ReturnValue = nil, 'Call to Mongo.indexCreate should return nil if successful');
end;

procedure TestTMongo.TestaddUser;
var
  ReturnValue: Boolean;
  password: string;
  Name: string;
begin
  Name := 'test_user';
  password := 'test_password';
  ReturnValue := FMongo.addUser(Name, password);
  Check(ReturnValue, 'Call to Mongo.addUser should return true');
  RemoveTest_user;
end;

procedure TestTMongo.TestaddUserWithDBParam;
var
  ReturnValue: Boolean;
  db: string;
  password: string;
  Name: string;
begin
  Name := 'test_user';
  password := 'test_password';
  db := 'test_db';
  ReturnValue := FMongo.addUser(Name, password, db);
  Check(ReturnValue, 'Call to Mongo.addUser should return true');
  RemoveTest_user;
end;

procedure TestTMongo.Testauthenticate;
var
  ReturnValue: Boolean;
  password: string;
  Name: string;
begin
  Name := 'test_user';
  password := 'test_password';
  ReturnValue := FMongo.addUser(Name, password);
  Check(ReturnValue, 'Call to Mongo.addUser should return true');
  ReturnValue := FMongo.authenticate(Name, password);
  RemoveTest_user;
  Check(ReturnValue, 'Call to Mongo.authenticate with good credentials should return True');
end;

procedure TestTMongo.TestauthenticateWithSpecificDB;
var
  ReturnValue: Boolean;
  db: string;
  password: string;
  Name: string;
begin
  Name := 'test_user';
  password := 'test_password';
  ReturnValue := FMongo.addUser(Name, password);
  Check(ReturnValue, 'Call to Mongo.addUser should return true');
  db := 'admin';
  ReturnValue := FMongo.authenticate(Name, password, db);
  RemoveTest_user;
  Check(ReturnValue, 'Call to Mongo.authenticate with good credentials and specific db should return True');
end;

procedure TestTMongo.TestauthenticateFail;
var
  ReturnValue: Boolean;
  password: string;
  Name: string;
begin
  Name := 'Bla';
  Password := 'Fake';
  ReturnValue := FMongo.authenticate(Name, password);
  Check(not ReturnValue, 'Call to Mongo.authenticate with fake credentials should return False');
end;

procedure TestTMongo.TestcommandWithBson;
var
  ReturnValue: IBson;
  command: IBson;
  db: string;
begin
  Create_test_db;
  command := BSON(['isMaster', null]);
  db := 'test_db';
  ReturnValue := FMongo.command(db, command);
  Check(ReturnValue <> nil, 'Call to Mongo.command should return <> nil');
  CheckEquals(True, ReturnValue.Value('ismaster'), 'ismaster should be equals to True');
end;

procedure TestTMongo.TestcommandWithArgs;
var
  ReturnValue: IBson;
  arg: Variant;
  cmdstr: string;
  db: string;
begin
  Create_test_db;
  db := 'test_db';
  cmdstr := 'isMaster';
  arg := null;
  ReturnValue := FMongo.command(db, cmdstr, arg);
  Check(ReturnValue <> nil, 'Call to Mongo.command should return <> nil');
  CheckEquals(True, ReturnValue.Value('ismaster'), 'ismaster should be equals to True');
end;

procedure TestTMongo.TestgetLastErr;
var
  ReturnValue: IBson;
  db: string;
begin
  db := 'test_db';
  ReturnValue := FMongo.getLastErr(db);
  Check(ReturnValue = nil, 'Call to Mongo.getLastErr should return = nil');
end;

procedure TestTMongo.TestgetPrevErr;
var
  ReturnValue: IBson;
  db: string;
begin
  db := 'test_db';
  ReturnValue := FMongo.getPrevErr(db);
  Check(ReturnValue = nil, 'Call to Mongo.getLastErr should return = nil');
end;

procedure TestTMongo.TestresetErr;
var
  db: string;
begin
  FMongo.resetErr(db);
  Check(True);
end;

procedure TestTMongo.TestgetServerErr;
var
  ReturnValue: Integer;
begin
  ReturnValue := FMongo.getServerErr;
  CheckEquals(0, ReturnValue, 'Error code should be equals to zero');
end;

procedure TestTMongo.TestgetServerErrString;
var
  ReturnValue: string;
begin
  ReturnValue := FMongo.getServerErrString;
  CheckEqualsString('', ReturnValue, 'Error string should be equals to blank string');
end;

procedure TestTMongo.TestFourThreads;
const
  ThreadCount = 4;
var
  ts : array of TMongoThread;
  i : integer;
begin
  SetLength (ts, ThreadCount);
  for I := low(ts) to high(ts) do
    ts[i] := TMongoThread.Create(self);
  try
    for I := low(ts) to high(ts) do
      ts[i].Resume;
    for I := low(ts) to high(ts) do
      ts[i].WaitFor;
    for I := low(ts) to high(ts) do
      CheckEqualsString('', ts[i].ErrorStr, 'ErrorString should be equals to blank string');
  finally
    for I := low(ts) to high(ts) do
      ts[i].Free;
  end;
end;

procedure TestTMongo.TestUseWriteConcern;
var
  wc : IWriteConcern;
begin
  Create_test_db;
  wc := NewWriteConcern;
  wc.j := 1;
  wc.finish;
  FMongo.setWriteConcern(wc);
  InsertAndCheckBson(1, 'Value1');
  FMongo.setWriteConcern(nil);
  InsertAndCheckBson(2, 'Value2');
end;

procedure TestTMongo.TestTryToUseUnfinishedWriteConcern;
var
  wc : IWriteConcern;
begin
  wc := NewWriteConcern;
  wc.j := 1;
  try
    FMongo.setWriteConcern(wc);
    Fail('Should have failed with error that tried to use unfinished writeconcern');
  except
    on E : EMongo do Check(pos('unfinished', E.Message) > 0, 'Exception expected should be that tried to use unfinished writeconcern');
  end;
end;

{ TestTMongoReplset }

function TestTMongoReplset.CreateMongo: TMongo;
begin
  Result := TMongoReplset.Create('foo');
  with Result as TMongoReplset do
    begin
      addSeed('127.0.0.1:27018');
      addSeed('127.0.0.1:27019');
      addSeed('127.0.0.1:27020');
    end;
end;

function TestTMongoReplset.GetExpectedPrimary: String;
begin
  Result := '127.0.0.1:27018';
end;

procedure TestTMongoReplset.SetUp;
begin
  inherited;
  StartReplSet;
  FMongoReplset := FMongo as TMongoReplset;
  FMongoReplset.Connect;
end;

procedure TestTMongoReplset.TearDown;
begin
  inherited;
  FMongoReplset := nil;
end;

procedure TestTMongoReplset.TestgetHost;
var
  i, n: Integer;
  List : TStringList;
begin
  n := FMongoReplset.getHostCount;
  CheckEquals(3, n, 'Host count should be equals to 3');
  List := TStringList.Create;
  try
    List.Sorted := True;
    for i := 0 to n - 1 do
      List.Add(FMongoReplset.getHost(i));
    CheckEqualsString('127.0.0.1:27018', List[0], 'First host should be "127.0.0.1:27018"');
    CheckEqualsString('127.0.0.1:27019', List[1], 'First host should be "127.0.0.1:27019"');
    CheckEqualsString('127.0.0.1:27020', List[2], 'First host should be "127.0.0.1:27020"');
  finally
    List.Free;
  end;
end;

{ TestIMongoCursor }

const
  SampleDataCount = 1000;
  SampleDataDB = 'test_db.sampledata';

procedure TestIMongoCursor.DeleteSampleData;
begin
  FMongo.drop(PAnsiChar(SampleDataDB));
end;

procedure TestIMongoCursor.SetUp;
begin
  inherited;
  FIMongoCursor := NewMongoCursor;
  StartReplSet;
  FMongo := TMongoReplset.Create('foo');
  FMongo.addSeed('127.0.0.1:27018');
  FMongo.addSeed('127.0.0.1:27019');
  FMongo.addSeed('127.0.0.1:27020');
  FMongo.Connect;
end;

procedure TestIMongoCursor.SetupData;
var
  b : IBsonBuffer;
  i : integer;
  s : AnsiString;
begin
  for I := 0 to SampleDataCount - 1 do
    begin
      b := NewBsonBuffer;
      b.Append(PAnsiChar('ID'), i);
      s := Format('STR_%0.4d', [SampleDataCount - i]);
      b.AppendStr(PAnsiChar('STRVAL'), PAnsiChar(s));
      FMongo.Insert(PAnsiChar(SampleDataDB), b.finish);
    end;
end;

procedure TestIMongoCursor.TearDown;
begin
  DeleteSampleData;
  FIMongoCursor := nil;
  FMongo.dropDatabase('test_db');
  FMongo.Free;
  if FMongoSecondary <> nil then
    FreeAndNil(FMongoSecondary);
  inherited;
end;

procedure TestIMongoCursor.TestGetConn;
var
  ReturnValue: TMongo;
begin
  FIMongoCursor.Conn := FMongo;
  ReturnValue := FIMongoCursor.GetConn;
  Check(ReturnValue = FMongo, 'FIMongoCursor.GetConn should be equals to FMongo');
end;

procedure TestIMongoCursor.TestGetFields;
var
  AFields : IBson;
  ReturnValue: IBson;
begin
  SetupData;
  AFields := BSON(['ID', 1]);
  FIMongoCursor.Fields := AFields;
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return True');
  Check(FIMongoCursor.Next, 'Call to FIMongoCursor.Next should return True');
  ReturnValue := FIMongoCursor.Fields;
  Check(ReturnValue = AFields, 'Call to FIMongoCursor.GetFields should return a non-nil Bson object');
end;

procedure TestIMongoCursor.TestGetHandle;
var
  ReturnValue: Pointer;
begin
  FMongo.find(SampleDataDB, FIMongoCursor); // This is needed to populate the iterator handle
  ReturnValue := FIMongoCursor.Handle;
  Check(ReturnValue <> nil, 'Call to FIMongoCursor.Handle should return a value <> nil');
end;

procedure TestIMongoCursor.TestGetLimit;
var
  ReturnValue: Integer;
begin
  FIMongoCursor.Limit := 10;
  ReturnValue := FIMongoCursor.GetLimit;
  CheckEquals(10, ReturnValue, 'FIMongoCursor.Limit should be equals to 10');
end;

procedure TestIMongoCursor.TestGetOptions;
var
  ReturnValue: Integer;
begin
  FIMongoCursor.Options := cursorPartial;
  ReturnValue := FIMongoCursor.GetOptions;
  CheckEquals(cursorPartial, ReturnValue, 'FIMongoCursor.Options should be equals to cursorPartial');
end;

procedure TestIMongoCursor.TestGetQuery;
var
  ReturnValue: IBson;
  AQuery : IBson;
begin
  AQuery := BSON(['ID', 0]);
  FIMongoCursor.Query := AQuery;
  ReturnValue := FIMongoCursor.Query;
  Check(ReturnValue = AQuery, 'FIMongoCursor.Query should return value equal to AQuery');
end;

procedure TestIMongoCursor.TestGetSkip;
var
  ReturnValue: Integer;
begin
  FIMongoCursor.Skip := 10;
  ReturnValue := FIMongoCursor.GetSkip;
  CheckEquals(10, ReturnValue, 'Call to FIMongoCursor.Skip should be equals to 10');
end;

procedure TestIMongoCursor.TestGetSort;
var
  ASort : IBson;
  ReturnValue: IBson;
begin
  ASort := BSON(['ID', True]);
  FIMongoCursor.Sort := ASort;
  ReturnValue := FIMongoCursor.GetSort;
  Check(ReturnValue = FIMongoCursor.Sort, 'Call to FIMongoCursor.Sort should return value equals to ASort');
end;

procedure TestIMongoCursor.TestNext;
var
  ReturnValue: Boolean;
begin
  FMongo.find(SampleDataDB, FIMongoCursor);
  ReturnValue := FIMongoCursor.Next;
  Check(not ReturnValue, 'FIMongoCursor.Next should return false when trying to get cursor to collection without data');
  SetupData;
  FMongo.find(SampleDataDB, FIMongoCursor);
  ReturnValue := FIMongoCursor.Next;
  Check(ReturnValue, 'FIMongoCursor.Next should return true when trying to get cursor to collection with data');
end;

procedure TestIMongoCursor.TestSetFields;
var
  v : Variant;
begin
  SetupData;
  FIMongoCursor.Fields := BSON(['ID', 1]);
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return True');
  Check(FIMongoCursor.Next, 'Call to FIMongoCursor.Next should return true');
  v := FIMongoCursor.Value.Value('ID');
  Check(not VarIsNull(v), 'Value returned by FIMongoCursor.Value.Value("ID") should be different from variant NULL');
  v := FIMongoCursor.Value.Value('STRVAL');
  Check(VarIsNull(v), 'Value returned by FIMongoCursor.Value.Value("STRVAL") should be variant NULL');

  FIMongoCursor.Fields := BSON(['ID', 1, 'STRVAL', 1]);
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return True');
  Check(FIMongoCursor.Next, 'Call to FIMongoCursor.Next should return true');
  v := FIMongoCursor.Value.Value('ID');
  Check(not VarIsNull(v), 'Value returned by FIMongoCursor.Value.Value("ID") should be different from variant NULL');
  v := FIMongoCursor.Value.Value('STRVAL');
  Check(not VarIsNull(v), 'Value returned by FIMongoCursor.Value.Value("STRVAL") should be different from variant NULL');
end;

procedure TestIMongoCursor.TestSetLimit;
var
  n : integer;
begin
  SetupData;
  FIMongoCursor.Limit := 10;
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return True');
  n := 0;
  while FIMongoCursor.Next do
    inc(n);
  CheckEquals(10, n, 'Number of Bson objects returned should be equals to 10');  
end;

procedure TestIMongoCursor.TestSetOptions;
begin
  FMongoSecondary := TMongo.Create('127.0.0.1:27019');
  SetupData;
  try
    FMongoSecondary.find(SampleDataDB, FIMongoCursor);
    Fail('Call to FMongoSecondary.Find should error out and it didn''t because no option to read from Secondary was set');
  except
    on E : Exception do Check(pos('not master', E.Message) > 0, 'Call should have errored our because Secondary option was not set');
  end;
  FIMongoCursor := nil;
  FIMongoCursor := NewMongoCursor;
  FIMongoCursor.Options := cursorSlaveOk;
  Check(FMongoSecondary.find(SampleDataDB, FIMongoCursor), 'Call to FMongoSecondary.Find should return True');
  FIMongoCursor := nil;
end;

procedure TestIMongoCursor.TestSetQuery;
var
  n : integer;
begin
  SetupData;
  FIMongoCursor.Query := BSON(['ID', 0]);
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return True');
  n := 0;
  while FIMongoCursor.Next do
    inc(n);
  CheckEquals(1, n, 'Number of objects returned should be equals to 1');
end;

procedure TestIMongoCursor.TestSetSkip;
var
  n: Integer;
begin
  SetupData;
  FIMongoCursor.Skip := SampleDataCount - 50;
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return true');
  n := 0;
  while FIMongoCursor.Next do
    inc(n);
  CheckEquals(50, n, 'Number of objects returned should be equals to 1');
end;

procedure TestIMongoCursor.TestSetSort;
var
  Prev, Value : String;
  n : integer;
begin
  SetupData;
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return true');
  Prev := 'STR_' + IntToStr(SampleDataCount + 1);
  n := 0;
  while FIMongoCursor.Next do
    begin
      Value := FIMongoCursor.Value.Value('STRVAL');
      Check(Value < Prev, 'Value should be lesser than previous value');
      Prev := Value;
      inc(n);
    end;
  CheckEquals(SampleDataCount, n, 'Number of objects returned should be ' + IntToStr(SampleDataCount));
  FMongo.indexCreate(SampleDataDB, 'STRVAL');
  FIMongoCursor := NewMongoCursor;
  FIMongoCursor.Sort := BSON(['STRVAL', True]);
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return true');
  Prev := 'STR_0000';
  n := 0;
  while FIMongoCursor.Next do
    begin
      Value := FIMongoCursor.Value.Value('STRVAL');
      Check(Value > Prev, 'Value should be higher than previous value');
      Prev := Value;
      inc(n);
    end;
   CheckEquals(SampleDataCount, n, 'Number of objects returned should be ' + IntToStr(SampleDataCount));
end;

procedure TestIMongoCursor.TestValue;
var
  ReturnValue: IBson;
begin
  SetupData;
  Check(FMongo.find(SampleDataDB, FIMongoCursor), 'Call to FMongo.Find should return True');
  FIMongoCursor.Next;
  ReturnValue := FIMongoCursor.Value;
  Check(ReturnValue <> nil, 'Call to FIMongoCursor.Value should return a value <> nil');
end;

{ TMongoThread }

constructor TMongoThread.Create(AMongoTest: TestTMongo);
begin
  inherited Create(True);
  FMongoTest := AMongoTest;
end;

procedure TMongoThread.Execute;
const
  ObjCount = 5000;
var
  AMongo : TMongo;
  Buf : IBsonBuffer;
  b, q : IBson;
  i : integer;
  OID : IBsonOID;
  n : Integer;
  Ids : array [0..ObjCount] of Integer;
begin
  try
    AMongo := FMongoTest.CreateMongo;
    try
      if AMongo is TMongoReplset then
        (AMongo as TMongoReplset).Connect;
      for I := 0 to ObjCount do
        begin
          Buf := NewBsonBuffer;
          OID := NewBsonOID;
          Buf.Append(PAnsiChar('ID'), OID);
          n := Random(1024);
          Buf.Append(PAnsiChar('NUM'), n);
          Buf.AppendStr(PAnsiChar('STRDATA'), PAnsiChar('1234' + IntToStr(i)));
          b := Buf.finish;
          Ids[i] := n;
          AMongo.Insert('test_db.test_thread', b);
        end;
      for I := 0 to ObjCount do
        begin
          q := BSON(['NUM', Ids[i]]);
          b := AMongo.findOne('test_db.test_thread', q);
          if (b = nil) or (b.Value(PAnsiChar('NUM')) <> Ids[i]) then
            raise Exception.Create('Object not found');
        end;  
      Sleep(500);  
    finally
      AMongo.Free;
    end;
  except
    on E : Exception do ErrorStr := E.Message;
  end;
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTMongo.Suite);
  RegisterTest(TestTMongoReplset.Suite);
  RegisterTest(TestIMongoCursor.Suite);
finalization
  if MongoStarted then
    ShutDownMongoDB;
end.

