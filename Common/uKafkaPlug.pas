unit uKafkaPlug;

interface

uses
  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, Windows, Math,
  ActiveX, Generics.Collections, SyncObjs, RegularExpressions,
  uQuote2DB, uQuoteFile, uQuoteBroadcast, memds, VirtualTable ,
  uLog, utils.queues, uCRCTools;

type
{测试方法

  Kafka创建”FundData“主题
  ./bin/kafka-topics --create --zookeeper localhost:2181 --replication-factor 1 --partitions 2 --topic FundData


  ./kafka-console-producer --broker-list localhost:9092 --topic FundData

  ./kafka-console-consumer --zookeeper localhost:2181 --topic TEST --from-beginning

}

  rd_kafka_s = record
  end;

  rd_kafka_t = rd_kafka_s;
  prd_kafka_t = ^rd_kafka_t;

  rd_kafka_topic_s = record
  end;

  rd_kafka_topic_t = rd_kafka_topic_s;
  prd_kafka_topic_t = ^rd_kafka_topic_t;

  rd_kafka_conf_s = record
  end;

  rd_kafka_conf_t = rd_kafka_conf_s;
  prd_kafka_conf_t = ^rd_kafka_conf_t;

  rd_kafka_topic_conf_s = record
  end;

  rd_kafka_topic_conf_t = rd_kafka_topic_conf_s;
  prd_kafka_topic_conf_t = ^rd_kafka_topic_conf_t;

  rd_kafka_queue_s = record
  end;

  rd_kafka_queue_t = rd_kafka_queue_s;
  prd_kafka_queue_t = ^rd_kafka_queue_t;

rd_kafka_resp_err_t = (
    (* Internal errors to rdkafka: *)
    (* * Begin internal error codes *)
    RD_KAFKA_RESP_ERR__BEGIN = -200,
    (* * Received message is incorrect *)
    RD_KAFKA_RESP_ERR__BAD_MSG = -199,
    (* * Bad/unknown compression *)
    RD_KAFKA_RESP_ERR__BAD_COMPRESSION = -198,
    (* * Broker is going away *)
    RD_KAFKA_RESP_ERR__DESTROY = -197,
    (* * Generic failure *)
    RD_KAFKA_RESP_ERR__FAIL = -196,
    (* * Broker transport failure *)
    RD_KAFKA_RESP_ERR__TRANSPORT = -195,
    (* * Critical system resource *)
    RD_KAFKA_RESP_ERR__CRIT_SYS_RESOURCE = -194,
    (* * Failed to resolve broker *)
    RD_KAFKA_RESP_ERR__RESOLVE = -193,
    (* * Produced message timed out *)
    RD_KAFKA_RESP_ERR__MSG_TIMED_OUT = -192,
    (* * Reached the end of the topic+partition queue on
      * the broker. Not really an error. *)
    RD_KAFKA_RESP_ERR__PARTITION_EOF = -191,
    (* * Permanent: Partition does not exist in cluster. *)
    RD_KAFKA_RESP_ERR__UNKNOWN_PARTITION = -190,
    (* * File or filesystem error *)
    RD_KAFKA_RESP_ERR__FS = -189,
    (* * Permanent: Topic does not exist in cluster. *)
    RD_KAFKA_RESP_ERR__UNKNOWN_TOPIC = -188,
    (* * All broker connections are down. *)
    RD_KAFKA_RESP_ERR__ALL_BROKERS_DOWN = -187,
    (* * Invalid argument, or invalid configuration *)
    RD_KAFKA_RESP_ERR__INVALID_ARG = -186,
    (* * Operation timed out *)
    RD_KAFKA_RESP_ERR__TIMED_OUT = -185,
    (* * Queue is full *)
    RD_KAFKA_RESP_ERR__QUEUE_FULL = -184,
    (* * ISR count < required.acks *)
    RD_KAFKA_RESP_ERR__ISR_INSUFF = -183,
    (* * Broker node update *)
    RD_KAFKA_RESP_ERR__NODE_UPDATE = -182,
    (* * SSL error *)
    RD_KAFKA_RESP_ERR__SSL = -181,
    (* * Waiting for coordinator to become available. *)
    RD_KAFKA_RESP_ERR__WAIT_COORD = -180,
    (* * Unknown client group *)
    RD_KAFKA_RESP_ERR__UNKNOWN_GROUP = -179,
    (* * Operation in progress *)
    RD_KAFKA_RESP_ERR__IN_PROGRESS = -178,
    (* * Previous operation in progress, wait for it to finish. *)
    RD_KAFKA_RESP_ERR__PREV_IN_PROGRESS = -177,
    (* * This operation would interfere with an existing subscription *)
    RD_KAFKA_RESP_ERR__EXISTING_SUBSCRIPTION = -176,
    (* * Assigned partitions (rebalance_cb) *)
    RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS = -175,
    (* * Revoked partitions (rebalance_cb) *)
    RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS = -174,
    (* * Conflicting use *)
    RD_KAFKA_RESP_ERR__CONFLICT = -173,
    (* * Wrong state *)
    RD_KAFKA_RESP_ERR__STATE = -172,
    (* * Unknown protocol *)
    RD_KAFKA_RESP_ERR__UNKNOWN_PROTOCOL = -171,
    (* * Not implemented *)
    RD_KAFKA_RESP_ERR__NOT_IMPLEMENTED = -170,
    (* * Authentication failure *)
    RD_KAFKA_RESP_ERR__AUTHENTICATION = -169,
    (* * No stored offset *)
    RD_KAFKA_RESP_ERR__NO_OFFSET = -168,
    (* * Outdated *)
    RD_KAFKA_RESP_ERR__OUTDATED = -167,
    (* * Timed out in queue *)
    RD_KAFKA_RESP_ERR__TIMED_OUT_QUEUE = -166,

    (* * End internal error codes *)
    RD_KAFKA_RESP_ERR__END = -100,

    (* Kafka broker errors: *)
    (* * Unknown broker error *)
    RD_KAFKA_RESP_ERR_UNKNOWN = -1,
    (* * Success *)
    RD_KAFKA_RESP_ERR_NO_ERROR = 0,
    (* * Offset out of range *)
    RD_KAFKA_RESP_ERR_OFFSET_OUT_OF_RANGE = 1,
    (* * Invalid message *)
    RD_KAFKA_RESP_ERR_INVALID_MSG = 2,
    (* * Unknown topic or partition *)
    RD_KAFKA_RESP_ERR_UNKNOWN_TOPIC_OR_PART = 3,
    (* * Invalid message size *)
    RD_KAFKA_RESP_ERR_INVALID_MSG_SIZE = 4,
    (* * Leader not available *)
    RD_KAFKA_RESP_ERR_LEADER_NOT_AVAILABLE = 5,
    (* * Not leader for partition *)
    RD_KAFKA_RESP_ERR_NOT_LEADER_FOR_PARTITION = 6,
    (* * Request timed out *)
    RD_KAFKA_RESP_ERR_REQUEST_TIMED_OUT = 7,
    (* * Broker not available *)
    RD_KAFKA_RESP_ERR_BROKER_NOT_AVAILABLE = 8,
    (* * Replica not available *)
    RD_KAFKA_RESP_ERR_REPLICA_NOT_AVAILABLE = 9,
    (* * Message size too large *)
    RD_KAFKA_RESP_ERR_MSG_SIZE_TOO_LARGE = 10,
    (* * StaleControllerEpochCode *)
    RD_KAFKA_RESP_ERR_STALE_CTRL_EPOCH = 11,
    (* * Offset metadata string too large *)
    RD_KAFKA_RESP_ERR_OFFSET_METADATA_TOO_LARGE = 12,
    (* * Broker disconnected before response received *)
    RD_KAFKA_RESP_ERR_NETWORK_EXCEPTION = 13,
    (* * Group coordinator load in progress *)
    RD_KAFKA_RESP_ERR_GROUP_LOAD_IN_PROGRESS = 14,
    (* * Group coordinator not available *)
    RD_KAFKA_RESP_ERR_GROUP_COORDINATOR_NOT_AVAILABLE = 15,
    (* * Not coordinator for group *)
    RD_KAFKA_RESP_ERR_NOT_COORDINATOR_FOR_GROUP = 16,
    (* * Invalid topic *)
    RD_KAFKA_RESP_ERR_TOPIC_EXCEPTION = 17,
    (* * Message batch larger than configured server segment size *)
    RD_KAFKA_RESP_ERR_RECORD_LIST_TOO_LARGE = 18,
    (* * Not enough in-sync replicas *)
    RD_KAFKA_RESP_ERR_NOT_ENOUGH_REPLICAS = 19,
    (* * Message(s) written to insufficient number of in-sync replicas *)
    RD_KAFKA_RESP_ERR_NOT_ENOUGH_REPLICAS_AFTER_APPEND = 20,
    (* * Invalid required acks value *)
    RD_KAFKA_RESP_ERR_INVALID_REQUIRED_ACKS = 21,
    (* * Specified group generation id is not valid *)
    RD_KAFKA_RESP_ERR_ILLEGAL_GENERATION = 22,
    (* * Inconsistent group protocol *)
    RD_KAFKA_RESP_ERR_INCONSISTENT_GROUP_PROTOCOL = 23,
    (* * Invalid group.id *)
    RD_KAFKA_RESP_ERR_INVALID_GROUP_ID = 24,
    (* * Unknown member *)
    RD_KAFKA_RESP_ERR_UNKNOWN_MEMBER_ID = 25,
    (* * Invalid session timeout *)
    RD_KAFKA_RESP_ERR_INVALID_SESSION_TIMEOUT = 26,
    (* * Group rebalance in progress *)
    RD_KAFKA_RESP_ERR_REBALANCE_IN_PROGRESS = 27,
    (* * Commit offset data size is not valid *)
    RD_KAFKA_RESP_ERR_INVALID_COMMIT_OFFSET_SIZE = 28,
    (* * Topic authorization failed *)
    RD_KAFKA_RESP_ERR_TOPIC_AUTHORIZATION_FAILED = 29,
    (* * Group authorization failed *)
    RD_KAFKA_RESP_ERR_GROUP_AUTHORIZATION_FAILED = 30,
    (* * Cluster authorization failed *)
    RD_KAFKA_RESP_ERR_CLUSTER_AUTHORIZATION_FAILED = 31,
    (* * Invalid timestamp *)
    RD_KAFKA_RESP_ERR_INVALID_TIMESTAMP = 32,
    (* * Unsupported SASL mechanism *)
    RD_KAFKA_RESP_ERR_UNSUPPORTED_SASL_MECHANISM = 33,
    (* * Illegal SASL state *)
    RD_KAFKA_RESP_ERR_ILLEGAL_SASL_STATE = 34,
    (* * Unuspported version *)
    RD_KAFKA_RESP_ERR_UNSUPPORTED_VERSION = 35,

    RD_KAFKA_RESP_ERR_END_ALL);

  (* *
    * @brief Error code value, name and description.
    *        Typically for use with language bindings to automatically expose
    *        the full set of librdkafka error codes.
  *)
  rd_kafka_err_desc = record
    code: rd_kafka_resp_err_t; (* *< Error code *)
    name: PAnsiChar; (* *< Error name, same as code enum sans prefix *)
    desc: PAnsiChar; (* *< Human readable error description. *)
  end;

  prd_kafka_err_desc = ^rd_kafka_err_desc;
  rd_kafka_conf_res_t = (RD_KAFKA_CONF_UNKNOWN = -2, (* *< Unknown configuration name. *)
    RD_KAFKA_CONF_INVALID = -1, (* *< Invalid configuration value. *)
    RD_KAFKA_CONF_OK = 0 (* *< Configuration okay *)
    );

rd_kafka_message_s = record
    err: rd_kafka_resp_err_t; (* *< Non-zero for error signaling. *)
    rkt: prd_kafka_topic_t; (* *< Topic *)
    partition: Int32; (* *< Partition *)
    payload: Pointer; (* *< Producer: original message payload.
      * Consumer: Depends on the value of \c err :
      * - \c err==0: Message payload.
      * - \c err!=0: Error string *)
    len: size_t; (* *< Depends on the value of \c err :
      * - \c err==0: Message payload length
      * - \c err!=0: Error string length *)
    key: Pointer; (* *< Depends on the value of \c err :
      * - \c err==0: Optional message key *)
    key_len: size_t; (* *< Depends on the value of \c err :
      * - \c err==0: Optional message key length *)
    offset: Int64; (* *< Consume:
      * - Message offset (or offset for error
      *   if \c err!=0 if applicable).
      * - dr_msg_cb:
      *   Message offset assigned by broker.
      *   If \c produce.offset.report is set then
      *   each message will have this field set,
      *   otherwise only the last message in
      *   each produced internal batch will
      *   have this field set, otherwise 0. *)
    _private: Pointer; (* *< Consume:
      *  - rdkafka private pointer: DO NOT MODIFY
      *  - dr_msg_cb:
      *    msg_opaque from produce() call *)
  end;

  rd_kafka_message_t = rd_kafka_message_s;
  prd_kafka_message_t = ^rd_kafka_message_t;
  rd_kafka_type_t = (RD_KAFKA_PRODUCER, (* *< Producer client *)
    RD_KAFKA_CONSUMER (* *< Consumer client *)
    );

  dr_msg_cb = procedure(rk: prd_kafka_t; rkmessage: prd_kafka_message_t; opaque: Pointer); cdecl;
const
  RD_KAFKA_PARTITION_UA = UInt32(-1);
  RD_KAFKA_MSG_F_FREE = $1; (* *< Delegate freeing of payload to rdkafka. *)
  RD_KAFKA_MSG_F_COPY = $2; (* *< rdkafka will make a copy of the payload. *)
  RD_KAFKA_MSG_F_BLOCK = $4; (* *< Block produce*() on message queue full.>*)

type
  TKafkaPlug = class(TQuoteScanner)
  private
    FConfig: TQuoteScanConfig;
    FKafkaHandle : prd_kafka_conf_t;
    FProducerHandle : prd_kafka_t;//Producer instance handle
    FTopicHandle : prd_kafka_topic_t;//
    FBatchSize: Integer;
  protected
    procedure Init; override;
    procedure Uninit; override;
    procedure doStart; override;
    procedure doStop; override;
    procedure doWork; override;
    function GetToolName:string; override;
  public
    constructor Create(AScanConfig:TQuoteScanConfig; AFileConfig: TQuoteFileConfig); override;
  end;

  TTemplateItemConvertProc = function(AParameter:string; const AJSON:string; const AQuotation:PQuoteRecord):string of object;
  TKafkaMsgTemplate = class
  strict private
    class var FLastID: Cardinal;
    class var FTemplate:string;
    class var FItems:TDictionary<string, TTemplateItemConvertProc>;
    class function Template_SendDate(AParameter:string; const AJSON:string; const AQuotation:PQuoteRecord):string;
    class function Template_SendTime(AParameter:string; const AJSON:string; const AQuotation:PQuoteRecord):string;
    class function Template_Code(AParameter:string; const AJSON:string; const AQuotation:PQuoteRecord):string;
    class function Template_Abbr(AParameter:string; const AJSON:string; const AQuotation:PQuoteRecord):string;
    class function Template_NewestPrice(AParameter:string; const AJSON:string; const AQuotation:PQuoteRecord):string;
    class function Template_MarketTime(AParameter:string; const AJSON:string; const AQuotation:PQuoteRecord):string;
    class function Template_MsgID(AParameter:string; const AJSON:string; const AQuotation:PQuoteRecord):string;
  public
    class procedure Load;
    class function Format(const Argument:PQuoteRecord):string;
  end;

const
  KafkaMsgTemplateFileName:string = '.\KafkaTemplate.JSON';

implementation

const KAFKA_DLL = 'rdkafka.dll';
//function Kafka_conf_new: prd_kafka_conf_t; cdecl; external KAFKA_DLL name 'rd_kafka_conf_new';
//function Kafka_conf_set(conf: prd_kafka_conf_t; name: PAnsiChar; value: PAnsiChar; errstr: PAnsiChar; errstr_size: size_t): rd_kafka_conf_res_t; cdecl; external KAFKA_DLL name 'rd_kafka_conf_set';
//procedure kafka_conf_set_dr_msg_cb(conf: prd_kafka_conf_t; cb: dr_msg_cb); cdecl; external KAFKA_DLL name 'rd_kafka_conf_set_dr_msg_cb';
//function Kafka_new(&type: rd_kafka_type_t; conf: prd_kafka_conf_t; errstr: PAnsiChar; errstr_size: size_t): prd_kafka_t; cdecl;external KAFKA_DLL name 'rd_kafka_new';
//function Kafka_topic_new(rk: prd_kafka_t; topic: PAnsiChar; conf: prd_kafka_topic_conf_t): prd_kafka_topic_t; cdecl;external KAFKA_DLL name 'rd_kafka_topic_new';
//procedure Kafka_topic_destroy(rkt: prd_kafka_topic_t); cdecl;external KAFKA_DLL name 'rd_kafka_topic_destroy';
//procedure Kafka_destroy(rk: prd_kafka_t); cdecl;external KAFKA_DLL name 'rd_kafka_destroy';
//function Kafka_produce_batch(rkt: prd_kafka_topic_t; partition: Int32; msgflags: integer; rkmessages: prd_kafka_message_t; message_cnt: integer): integer; cdecl;external KAFKA_DLL name 'rd_kafka_produce_batch';
//function Kafka_flush(rk: prd_kafka_t; timeout_ms: integer): rd_kafka_resp_err_t; cdecl;external KAFKA_DLL name 'rd_kafka_flush';
//function Kafka_last_error: rd_kafka_resp_err_t; cdecl;external KAFKA_DLL name 'rd_kafka_last_error';
//function Kafka_poll(rk: prd_kafka_t; timeout_ms: integer): integer; cdecl;external KAFKA_DLL name 'rd_kafka_poll';


function Kafka_conf_new: prd_kafka_conf_t; cdecl; begin end;
function Kafka_conf_set(conf: prd_kafka_conf_t; name: PAnsiChar; value: PAnsiChar; errstr: PAnsiChar; errstr_size: size_t): rd_kafka_conf_res_t; cdecl; begin end;
procedure kafka_conf_set_dr_msg_cb(conf: prd_kafka_conf_t; cb: dr_msg_cb); cdecl; begin end;
function Kafka_new(&type: rd_kafka_type_t; conf: prd_kafka_conf_t; errstr: PAnsiChar; errstr_size: size_t): prd_kafka_t; cdecl;begin end;
function Kafka_topic_new(rk: prd_kafka_t; topic: PAnsiChar; conf: prd_kafka_topic_conf_t): prd_kafka_topic_t; cdecl;begin end;
procedure Kafka_topic_destroy(rkt: prd_kafka_topic_t); cdecl;begin end;
procedure Kafka_destroy(rk: prd_kafka_t); cdecl;begin end;
function Kafka_produce_batch(rkt: prd_kafka_topic_t; partition: Int32; msgflags: integer; rkmessages: prd_kafka_message_t; message_cnt: integer): integer; cdecl;begin end;
function Kafka_flush(rk: prd_kafka_t; timeout_ms: integer): rd_kafka_resp_err_t; cdecl;begin end;
function Kafka_last_error: rd_kafka_resp_err_t; cdecl;begin end;
function Kafka_poll(rk: prd_kafka_t; timeout_ms: integer): integer; cdecl;begin end;


procedure Kafka_MsgCB(rk: prd_kafka_t; rkmessage: prd_kafka_message_t; opaque: Pointer); cdecl;
begin
  uLog.Log.AddLog('kafka message callback ...');
  if rkmessage.err <> RD_KAFKA_RESP_ERR_NO_ERROR then
  begin
    log.AddLogFormat('Kafka Error[CB procedure], Error code:', [Integer(rkmessage.err)]);
  end;
end;
{ TKafkaPlug }

constructor TKafkaPlug.Create(AScanConfig: TQuoteScanConfig; AFileConfig: TQuoteFileConfig);
begin
  inherited;
  FConfig := AScanConfig;
  //确认扫描间隔（秒）
  ScanInterval := AScanConfig.Kafka.ScanInterval;
end;

procedure TKafkaPlug.doStart;
var
  errstr:array[1..512] of AnsiChar;
  brokers, topic: AnsiString;
begin
  inherited;
  FProducerHandle := nil;
  FTopicHandle := nil;

  brokers := FConfig.Kafka.Brokers;
  topic := FConfig.Kafka.Topic;

  //Init Kafka Config Instance...
  FKafkaHandle := Kafka_conf_new();
  //*创建broker集群*
  if Kafka_conf_set(FKafkaHandle, 'bootstrap.servers', @brokers[1],  @errstr[1], Length(errstr)) <> RD_KAFKA_CONF_OK then
  begin
    Log.AddLog('Kafka：Set bootstrap.servers Error！');
    Exit;
  end;
  //设置发送报告回调函数
  kafka_conf_set_dr_msg_cb(FKafkaHandle, Kafka_MsgCB);

  //创建producer实例
  FProducerHandle := kafka_new(RD_KAFKA_PRODUCER, FKafkaHandle, @errstr[1], Length(errstr));
  if not Assigned(FProducerHandle) then
  begin
    Log.AddLog('Kafka：Producer Init Failed！');
    Exit;
  end;
  //创建Topic实例
  FTopicHandle := kafka_topic_new(FProducerHandle, @topic[1], nil);
  if not Assigned(FTopicHandle) then
  begin
    Log.AddLog('Kafka：Topic Init Failed！');
    Exit;
  end;
end;

procedure TKafkaPlug.doStop;
begin
  inherited;
  //rd_kafka_flush(FProducerHandle, 10*1000);
  Kafka_topic_destroy(FTopicHandle);
  Kafka_destroy(FProducerHandle);
end;

procedure TKafkaPlug.doWork;
var
  tmp: Pointer; rec:PQuoteRecord;
  msg: AnsiString;
  k,i,rcode:Integer;
  err: rd_kafka_resp_err_t;
  buf_array: array of rd_kafka_message_s;
  msg_array: array of RawByteString;
begin
  SetLength(buf_array, FBatchSize);
  SetLength(msg_array, FBatchSize);
  //扫描行情入库队列
  while Active or (FChangeList.Size>0) do
  begin
    k := 0;
    while FChangeList.DeQueue(tmp) and (k<FBatchSize) do
    begin
      rec := tmp;
      msg_array[k] := AnsiToUtf8(TKafkaMsgTemplate.Format(tmp));
      //Format('%s,%s,%s,%f'#13#10,[FormatDateTime('yyyy-mm-dd hh:nn:ss', rec.Market.Time), rec.GetCode, rec.GetAbbr, rec.Close]);
      //buf_array[k].err := nil;
      buf_array[k].rkt := FTopicHandle;
      buf_array[k].partition := RD_KAFKA_PARTITION_UA;
      buf_array[k].payload := @msg_array[k][1];
      buf_array[k].len := Length(msg_array[k]);
      buf_array[k].key := nil;
      buf_array[k].key_len := 0;
      buf_array[k].offset := 0;
      buf_array[k]._private := nil;
      inc(k);
    end;
    if k>0 then
    begin
      rcode := Kafka_produce_batch(FTopicHandle, RD_KAFKA_PARTITION_UA, RD_KAFKA_MSG_F_COPY, @buf_array[0], k);
      //err := Kafka_flush(FProducerHandle, 1*1000);
      //log.AddLogFormat('Send To Kafka Message, [%d] count.', [k]);
      if rcode = -1 then
      begin
        err := Kafka_last_error();
        Kafka_poll(FProducerHandle,1000);
        log.AddLogFormat('Kafka: Send error, Code:%d', [Integer(err)]);
      end;
    end;
    Kafka_poll(FProducerHandle,0);
    sleep(5);
  end;

  for i := 0 to FBatchSize -1 do msg_array[i] := '';
  SetLength(buf_array, 0);
  SetLength(msg_array, 0);
end;

function TKafkaPlug.GetToolName: string;
begin
  result := 'Kafka插件';
end;

procedure TKafkaPlug.Init;
begin
  inherited;
  FBatchSize := 128;
end;

procedure TKafkaPlug.Uninit;
begin
  inherited;

end;

{ TKafkaMsgTemplate }

class function TKafkaMsgTemplate.Format(const Argument: PQuoteRecord): string;
var
  perArg:string;
  cb: TTemplateItemConvertProc;
begin
  if FTemplate = '' then Load;
  result := FTemplate;
  for perArg in FItems.Keys.ToArray() do
  begin
    cb := FItems[perArg];
    if Assigned(cb) then
      result := cb(perArg, result, Argument);
  end;
end;

class procedure TKafkaMsgTemplate.Load;
var
  r:TRegEx;
  m:TMatch;
  t,t1:string;
begin
  FlastID := GetTickCount;
  if not Assigned(FItems) then
    FItems := TDictionary<string, TTemplateItemConvertProc>.Create(1024);

  if TFile.Exists(KafkaMsgTemplateFileName) then
    FTemplate := TFile.ReadAllText(KafkaMsgTemplateFileName)
  else
    FTemplate := '{"Code": "#CODE","ABBR": "#ABBR","NewestPrice": "#NewestPrice","MarketTime": "#MarketTime"}';

  for m in r.Matches(FTemplate, '\#(\w+)', [roIgnoreCase]) do
    FItems.AddOrSetValue(m.Value, nil);

  for t1 in FItems.Keys.ToArray do
  begin
    t := UpperCase(t1);
    if t = '#MSG_ID' then FItems[t1] := Template_MsgID else
    if t = '#SENDDATE' then FItems[t1] := Template_SendDate else
    if t = '#SENDTIME' then FItems[t1] := Template_SendTime else
    if t = '#CODE' then FItems[t1] := Template_Code else
    if t = '#ABBR' then FItems[t1] := Template_Abbr else
    if t = '#NEWESTPRICE' then FItems[t1] := Template_NewestPrice else
    if t = '#MARKETTIME' then FItems[t1] := Template_MarketTime;
  end;
end;

class function TKafkaMsgTemplate.Template_Abbr(AParameter: string; const AJSON: string; const AQuotation: PQuoteRecord): string;
begin
  result := ReplaceText(AJSON, AParameter, AQuotation.Abbr);
end;

class function TKafkaMsgTemplate.Template_Code(AParameter: string; const AJSON: string; const AQuotation: PQuoteRecord): string;
begin
  result := ReplaceText(AJSON, AParameter, AQuotation.Code);
end;

class function TKafkaMsgTemplate.Template_MarketTime(AParameter: string; const AJSON: string; const AQuotation: PQuoteRecord): string;
begin
  result := ReplaceText(AJSON, AParameter, FormatDateTime('yyyy-mm-dd hh:nn:ss', AQuotation.Market.Time));
end;

class function TKafkaMsgTemplate.Template_MsgID(AParameter: string; const AJSON: string; const AQuotation: PQuoteRecord): string;
var
  tmpid:Cardinal;
begin
  tmpid := GetTickCount;
  if tmpid <= FLastID then tmpid := FLastID+1;
  FLastID := tmpID;

  result := ReplaceText(AJSON, AParameter,
    SysUtils.Format('%s-%d', [
      FormatDateTime('yyyymmdd-hns', now),FLastID])
    );
end;

class function TKafkaMsgTemplate.Template_NewestPrice(AParameter: string; const AJSON: string; const AQuotation: PQuoteRecord): string;
begin
  result := ReplaceText(AJSON, AParameter, SysUtils.Format('%.4f', [AQuotation.Last]));
end;

class function TKafkaMsgTemplate.Template_SendDate(AParameter: string; const AJSON: string; const AQuotation: PQuoteRecord): string;
begin
  result := ReplaceText(AJSON, AParameter, FormatDateTime('yyyymmdd', now));
end;

class function TKafkaMsgTemplate.Template_SendTime(AParameter: string; const AJSON: string; const AQuotation: PQuoteRecord): string;
begin
  result := ReplaceText(AJSON, AParameter, FormatDateTime('hnnss', now));
end;

end.
