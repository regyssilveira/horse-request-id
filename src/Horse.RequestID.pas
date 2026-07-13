unit Horse.RequestID;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
  {$IF DEFINED(FPC)}
    SysUtils,
  {$ELSE}
    System.SysUtils,
  {$ENDIF}
  Horse;

type
  THorseRequestIDConfig = record
  private
    FHeaderName: string;
  public
    property HeaderName: string read FHeaderName write FHeaderName;
    class function Default: THorseRequestIDConfig; static;
  end;

  THorseRequestID = class
  private
    FID: string;
  public
    constructor Create(const AID: string);
    property ID: string read FID;
    class function Get(const AReq: THorseRequest): string; static;
  end;

function RequestID: THorseCallback; overload;
function RequestID(const AConfig: THorseRequestIDConfig): THorseCallback; overload;
function RequestID(const AHeaderName: string): THorseCallback; overload;

implementation

{ THorseRequestIDConfig }

class function THorseRequestIDConfig.Default: THorseRequestIDConfig;
begin
  Result.FHeaderName := 'X-Request-ID';
end;

{ THorseRequestID }

constructor THorseRequestID.Create(const AID: string);
begin
  inherited Create;
  FID := AID;
end;

class function THorseRequestID.Get(const AReq: THorseRequest): string;
var
  LService: TObject;
begin
  Result := '';
  if Assigned(AReq) and Assigned(AReq.Services) then
  begin
    LService := AReq.Services.Resolve(THorseRequestID);
    if Assigned(LService) then
      Result := THorseRequestID(LService).ID;
  end;
end;

function GenerateRequestID: string;
var
  LGUID: TGUID;
begin
  if CreateGUID(LGUID) = 0 then
  begin
    Result := GUIDToString(LGUID);
    Result := StringReplace(Result, '{', '', [rfReplaceAll]);
    Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  end
  else
    Result := '';
end;

function RequestID(const AConfig: THorseRequestIDConfig): THorseCallback;
begin
  Result := procedure(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF})
  var
    LID: string;
    LHeader: string;
  begin
    LHeader := AConfig.HeaderName;
    if LHeader = '' then
      LHeader := 'X-Request-ID';

    // 1. Tentar obter do Header Customizado, X-Request-ID ou X-Correlation-ID
    LID := Req.Headers[LHeader];
    if LID = '' then
      LID := Req.Headers['X-Request-ID'];
    if LID = '' then
      LID := Req.Headers['X-Correlation-ID'];

    // 2. Se não existir, gerar um novo
    if LID = '' then
      LID := GenerateRequestID;

    // 3. Registrar no escopo da requisição
    Req.Services.Add(THorseRequestID, THorseRequestID.Create(LID));

    // 4. Injetar na resposta
    Res.RawWebResponse.SetCustomHeader(LHeader, LID);

    Next();
  end;
end;

function RequestID: THorseCallback;
begin
  Result := RequestID(THorseRequestIDConfig.Default);
end;

function RequestID(const AHeaderName: string): THorseCallback;
var
  LConfig: THorseRequestIDConfig;
begin
  LConfig.HeaderName := AHeaderName;
  Result := RequestID(LConfig);
end;

end.
