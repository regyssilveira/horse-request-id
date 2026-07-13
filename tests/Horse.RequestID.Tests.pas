unit Horse.RequestID.Tests;

interface

uses
  DUnitX.TestFramework,
  Horse,
  Horse.RequestID,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.SyncObjs;

type
  [TestFixture]
  TTestHorseRequestID = class
  private
    const TEST_PORT = 9089;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure TestRequestIDGeneratedWhenMissing;
    [Test]
    procedure TestRequestIDForwardedFromRequestHeader;
    [Test]
    procedure TestRequestIDForwardedFromCorrelationIDHeader;
    [Test]
    procedure TestRequestIDConcurrency;
  end;

implementation

{ TTestHorseRequestID }

procedure TTestHorseRequestID.SetupFixture;
begin
  THorse.Use(RequestID());

  THorse.Get('/test-id',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send(THorseRequestID.Get(Req));
    end);

  TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(TEST_PORT);
    end).Start;

  Sleep(1000); // Aguarda o servidor inicializar
end;

procedure TTestHorseRequestID.TearDownFixture;
begin
  THorse.StopListen;
  Sleep(500);
end;

procedure TTestHorseRequestID.TestRequestIDGeneratedWhenMissing;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get(Format('http://localhost:%d/test-id', [TEST_PORT]));
    
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContainsHeader('X-Request-ID'), 'A resposta deve conter o header X-Request-ID');
    Assert.IsNotEmpty(LResponse.HeaderValue['X-Request-ID'], 'O header X-Request-ID não deve estar vazio');
    Assert.AreEqual(LResponse.ContentAsString, LResponse.HeaderValue['X-Request-ID'], 'O ID no corpo deve ser o mesmo do header');
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseRequestID.TestRequestIDForwardedFromRequestHeader;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
begin
  LClient := THTTPClient.Create;
  try
    SetLength(LHeaders, 1);
    LHeaders[0].Name := 'X-Request-ID';
    LHeaders[0].Value := 'my-custom-request-id-123';

    LResponse := LClient.Get(Format('http://localhost:%d/test-id', [TEST_PORT]), nil, LHeaders);
    
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContainsHeader('X-Request-ID'), 'A resposta deve conter o header X-Request-ID');
    Assert.AreEqual('my-custom-request-id-123', LResponse.HeaderValue['X-Request-ID'], 'O ID deve ser encaminhado do request');
    Assert.AreEqual('my-custom-request-id-123', LResponse.ContentAsString, 'O ID no corpo deve ser o mesmo enviado no request');
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseRequestID.TestRequestIDForwardedFromCorrelationIDHeader;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
begin
  LClient := THTTPClient.Create;
  try
    SetLength(LHeaders, 1);
    LHeaders[0].Name := 'X-Correlation-ID';
    LHeaders[0].Value := 'my-correlation-id-999';

    LResponse := LClient.Get(Format('http://localhost:%d/test-id', [TEST_PORT]), nil, LHeaders);
    
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContainsHeader('X-Request-ID'), 'A resposta deve retornar sob X-Request-ID');
    Assert.AreEqual('my-correlation-id-999', LResponse.HeaderValue['X-Request-ID'], 'O ID deve ser extraído de X-Correlation-ID');
    Assert.AreEqual('my-correlation-id-999', LResponse.ContentAsString, 'O ID no corpo deve ser o mesmo de X-Correlation-ID');
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseRequestID.TestRequestIDConcurrency;
const
  NUM_THREADS = 10;
  REQS_PER_THREAD = 5;
var
  LTasks: array[0..NUM_THREADS - 1] of ITask;
  I: Integer;
  LFailed: Boolean;
  LFailMessage: string;
  LFailedCS: TCriticalSection;
begin
  LFailed := False;
  LFailMessage := '';
  LFailedCS := TCriticalSection.Create;
  try
    for I := 0 to NUM_THREADS - 1 do
    begin
      LTasks[I] := TTask.Create(
        procedure
        var
          LClient: THTTPClient;
          LResponse: IHTTPResponse;
          K: Integer;
          LRequestID: string;
        begin
          LClient := THTTPClient.Create;
          try
            for K := 1 to REQS_PER_THREAD do
            begin
              try
                LResponse := LClient.Get(Format('http://localhost:%d/test-id', [TEST_PORT]));
                
                if LResponse.StatusCode <> 200 then
                begin
                  LFailedCS.Enter;
                  LFailed := True;
                  LFailMessage := Format('Status code incorreto: esperado 200, recebido %d', [LResponse.StatusCode]);
                  LFailedCS.Leave;
                  Break;
                end;

                LRequestID := LResponse.HeaderValue['X-Request-ID'];
                if LRequestID = '' then
                begin
                  LFailedCS.Enter;
                  LFailed := True;
                  LFailMessage := 'Request ID vazio nos headers da resposta';
                  LFailedCS.Leave;
                  Break;
                end;

                if LResponse.ContentAsString <> LRequestID then
                begin
                  LFailedCS.Enter;
                  LFailed := True;
                  LFailMessage := Format('Inconsistência de ID: Header=%s, Content=%s', [LRequestID, LResponse.ContentAsString]);
                  LFailedCS.Leave;
                  Break;
                end;
              except
                on E: Exception do
                begin
                  LFailedCS.Enter;
                  LFailed := True;
                  LFailMessage := 'Erro na thread: ' + E.Message;
                  LFailedCS.Leave;
                  Break;
                end;
              end;
            end;
          finally
            LClient.Free;
          end;
        end);
      LTasks[I].Start;
    end;

    TTask.WaitForAll(LTasks);
    Assert.IsFalse(LFailed, 'Falha no teste de concorrência: ' + LFailMessage);
  finally
    LFailedCS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHorseRequestID);

end.
