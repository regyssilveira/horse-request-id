---
name: horse-request-id
description: Guidelines and workflows for developing and maintaining the horse-request-id middleware within the Horse framework.
---

# Uso e Desenvolvimento do Horse Request ID

Diretrizes e exemplos práticos para guiar modelos de linguagem (LLMs) na utilização correta deste middleware.

## 🟢 Como Registrar o Middleware

O middleware deve ser registrado no pipeline do Horse antes de qualquer rota ou controlador que necessite consumir o ID da requisição, idealmente no início das declarações do pipeline.

### Exemplo de Registro Padrão:
```delphi
uses
  Horse,
  Horse.RequestID;

begin
  THorse.Use(RequestID);
end;
```

### Exemplo de Registro com Header Customizado:
```delphi
THorse.Use(RequestID('X-Correlation-ID'));
```

## 🟢 Como Consumir o Request ID nos Handlers

Para recuperar o identificador único da requisição ativa em rotas ou outros middlewares subsequentes, utilize o método estático `THorseRequestID.Get(Req)`:

```delphi
THorse.Get('/api/v1/ping',
  procedure(Req: THorseRequest; Res: THorseResponse)
  var
    LRequestID: string;
  begin
    LRequestID := THorseRequestID.Get(Req);
    Res.Send(Format('{"id": "%s"}', [LRequestID]));
  end);
```

## 🟢 Tratamento de Erros e Exceções

O middleware é autossuficiente e não interrompe o pipeline de execução normal. Ele foi projetado para:
* Retornar uma string vazia `''` de forma segura caso `THorseRequestID.Get(Req)` seja chamado sem que o middleware tenha sido registrado previamente no pipeline do Horse, evitando erros de violação de acesso (*Access Violation*).
* Tratar de forma segura falhas do sistema operacional ao gerar GUIDs por meio da função `CreateGUID`, garantindo resiliência sob qualquer condição de carga.
