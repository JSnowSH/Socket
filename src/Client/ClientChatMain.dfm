object FrmClientChat: TFrmClientChat
  Left = 0
  Top = 0
  Caption = 'Cliente WebSocket - chat (THR.WebSocket)'
  ClientHeight = 442
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    624
    442)
  PixelsPerInch = 96
  TextHeight = 15
  object LblLog: TLabel
    Left = 24
    Top = 13
    Width = 66
    Height = 15
    Caption = 'Mensagens:'
  end
  object LblServidor: TLabel
    Left = 163
    Top = 13
    Width = 52
    Height = 15
    Anchors = [akTop]
    Caption = 'Servidor:'
  end
  object LblMensagem: TLabel
    Left = 24
    Top = 360
    Width = 65
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Mensagem:'
  end
  object LblDestino: TLabel
    Left = 24
    Top = 400
    Width = 100
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Destino (ou ALL):'
  end
  object LblNome: TLabel
    Left = 295
    Top = 400
    Width = 60
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Seu nome:'
  end
  object EdtServidor: TEdit
    Left = 221
    Top = 10
    Width = 113
    Height = 23
    Anchors = [akTop]
    TabOrder = 0
    Text = '127.0.0.1:8080'
    TextHint = 'host ou host:porta'
  end
  object BtnConectar: TButton
    Left = 340
    Top = 9
    Width = 89
    Height = 25
    Anchors = [akTop]
    Caption = 'Conectar'
    TabOrder = 1
    OnClick = BtnConectarClick
  end
  object BtnPing: TButton
    Left = 435
    Top = 9
    Width = 50
    Height = 25
    Anchors = [akTop]
    Caption = 'Ping'
    TabOrder = 7
    OnClick = BtnPingClick
  end
  object PnlStatus: TPanel
    Left = 491
    Top = 9
    Width = 109
    Height = 25
    Anchors = [akTop, akRight]
    Alignment = taRightJustify
    BevelOuter = bvNone
    Caption = 'Desconectado'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clMaroon
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 8
  end
  object MemLog: TMemo
    Left = 24
    Top = 40
    Width = 576
    Height = 307
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 6
  end
  object EdtMensagem: TEdit
    Left = 136
    Top = 357
    Width = 369
    Height = 23
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 2
    Text = 'Ola mundo'
    OnKeyPress = EdtMensagemKeyPress
  end
  object BtnEnviar: TButton
    Left = 511
    Top = 356
    Width = 89
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Enviar'
    TabOrder = 3
    OnClick = BtnEnviarClick
  end
  object EdtDestino: TEdit
    Left = 136
    Top = 397
    Width = 153
    Height = 23
    Anchors = [akLeft, akBottom]
    TabOrder = 4
    Text = 'ALL'
  end
  object EdtNome: TEdit
    Left = 363
    Top = 397
    Width = 142
    Height = 23
    Anchors = [akLeft, akBottom]
    TabOrder = 5
    Text = 'UserA'
  end
end
