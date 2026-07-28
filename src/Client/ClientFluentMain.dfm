object FrmClientFluent: TFrmClientFluent
  Left = 0
  Top = 0
  Caption = 'Cliente Pusher - THR.WebSocket (Laravel Reverb)'
  ClientHeight = 461
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    760
    461)
  PixelsPerInch = 96
  TextHeight = 15
  object LblServidor: TLabel
    Left = 24
    Top = 15
    Width = 46
    Height = 15
    Caption = 'Servidor:'
  end
  object LblAppKey: TLabel
    Left = 232
    Top = 15
    Width = 46
    Height = 15
    Caption = 'App key:'
  end
  object LblAuthURL: TLabel
    Left = 24
    Top = 81
    Width = 53
    Height = 15
    Caption = 'Auth URL:'
  end
  object LblToken: TLabel
    Left = 466
    Top = 81
    Width = 35
    Height = 15
    Caption = 'Token:'
  end
  object LblLog: TLabel
    Left = 24
    Top = 115
    Width = 63
    Height = 15
    Caption = 'Mensagens:'
  end
  object LblCanal: TLabel
    Left = 24
    Top = 385
    Width = 33
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Canal:'
  end
  object LblEvento: TLabel
    Left = 24
    Top = 424
    Width = 39
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Evento:'
  end
  object LblPayload: TLabel
    Left = 296
    Top = 424
    Width = 45
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Payload:'
  end
  object LblAppSecret: TLabel
    Left = 232
    Top = 48
    Width = 59
    Height = 15
    Caption = 'App secret:'
  end
  object EdtAuthURL: TEdit
    Left = 90
    Top = 78
    Width = 370
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 13
    TextHint = 
      'http://localhost:8000/broadcasting/auth (vazio = usa o app secre' +
      't)'
  end
  object EdtToken: TEdit
    Left = 514
    Top = 78
    Width = 222
    Height = 23
    Anchors = [akTop, akRight]
    PasswordChar = '*'
    TabOrder = 14
    TextHint = 'Bearer token (Sanctum/Passport)'
  end
  object EdtServidor: TEdit
    Left = 90
    Top = 12
    Width = 130
    Height = 23
    TabOrder = 0
    Text = '127.0.0.1:6001'
    TextHint = 'host ou host:porta'
  end
  object EdtAppKey: TEdit
    Left = 288
    Top = 12
    Width = 262
    Height = 23
    TabOrder = 1
    Text = '5e0e16ccda5d32cde34cfdd4e1a214f8'
    TextHint = 'PUSHER_APP_KEY'
  end
  object PnlStatus: TPanel
    Left = 578
    Top = 12
    Width = 158
    Height = 23
    Alignment = taRightJustify
    Anchors = [akTop, akRight]
    BevelOuter = bvNone
    Caption = 'Desconectado'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clMaroon
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 10
  end
  object EdtAppSecret: TEdit
    Left = 302
    Top = 45
    Width = 248
    Height = 23
    PasswordChar = '*'
    TabOrder = 12
    TextHint = 'PUSHER_APP_SECRET (canais privados, apenas testes)'
  end
  object BtnConectar: TButton
    Left = 24
    Top = 45
    Width = 100
    Height = 25
    Caption = 'Conectar'
    TabOrder = 2
    OnClick = BtnConectarClick
  end
  object BtnPing: TButton
    Left = 130
    Top = 45
    Width = 70
    Height = 25
    Caption = 'Ping'
    TabOrder = 3
    OnClick = BtnPingClick
  end
  object MemLog: TMemo
    Left = 24
    Top = 134
    Width = 712
    Height = 238
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 9
  end
  object EdtCanal: TEdit
    Left = 90
    Top = 382
    Width = 200
    Height = 23
    Anchors = [akLeft, akBottom]
    TabOrder = 4
    Text = 'pedidos'
    TextHint = 'canal, private-... ou presence-...'
  end
  object BtnInscrever: TButton
    Left = 296
    Top = 381
    Width = 100
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Inscrever'
    TabOrder = 5
    OnClick = BtnInscreverClick
  end
  object BtnCancelar: TButton
    Left = 402
    Top = 381
    Width = 100
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Cancelar'
    TabOrder = 6
    OnClick = BtnCancelarClick
  end
  object EdtEvento: TEdit
    Left = 90
    Top = 421
    Width = 200
    Height = 23
    Anchors = [akLeft, akBottom]
    TabOrder = 7
    Text = 'client-chat'
    TextHint = 'evento de cliente (client-...)'
  end
  object EdtPayload: TEdit
    Left = 349
    Top = 421
    Width = 275
    Height = 23
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 8
    Text = '{"msg":"Ola mundo"}'
    OnKeyPress = EdtPayloadKeyPress
  end
  object BtnEnviar: TButton
    Left = 636
    Top = 420
    Width = 100
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Enviar'
    TabOrder = 11
    OnClick = BtnEnviarClick
  end
end
