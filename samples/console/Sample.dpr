program Sample;

{$APPTYPE CONSOLE}

uses
  {$IF DEFINED(FPC)}
    SysUtils,
  {$ELSE}
    System.SysUtils,
  {$ENDIF}
  Horse,
  Horse.RequestID;

procedure Ping(Req: THorseRequest; Res: THorseResponse);
var
  LRequestID: string;
begin
  // Recupera o Request ID associado à requisição ativa
  LRequestID := THorseRequestID.Get(Req);
  
  // Retorna uma resposta JSON contendo o Request ID
  Res.Send(Format('{"message": "pong", "request_id": "%s"}', [LRequestID]));
end;

begin
  // Adiciona o middleware RequestID ao pipeline do Horse
  THorse.Use(RequestID());

  THorse.Get('/ping', Ping);

  WriteLn('Servidor Horse rodando na porta 9000...');
  THorse.Listen(9000);
end.
