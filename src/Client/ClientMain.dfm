object FClientMain: TFClientMain
  Left = 0
  Top = 0
  Caption = 'Delphi WebSocket Client'
  ClientHeight = 442
  ClientWidth = 624
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
    624
    442)
  PixelsPerInch = 96
  TextHeight = 15
  object Label1: TLabel
    Left = 24
    Top = 16
    Width = 63
    Height = 15
    Caption = 'Server Logs:'
  end
  object Label2: TLabel
    Left = 24
    Top = 360
    Width = 92
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Message to Send:'
  end
  object Label3: TLabel
    Left = 24
    Top = 400
    Width = 120
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Target Name (or ALL):'
  end
  object MemoLog: TMemo
    Left = 24
    Top = 37
    Width = 576
    Height = 310
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'Ready to connect...')
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object EditMsg: TEdit
    Left = 136
    Top = 357
    Width = 369
    Height = 23
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 1
    Text = 'Hello World'
  end
  object EditTarget: TEdit
    Left = 136
    Top = 397
    Width = 153
    Height = 23
    Anchors = [akLeft, akBottom]
    TabOrder = 2
    Text = 'ALL'
  end
  object BtnSend: TButton
    Left = 511
    Top = 356
    Width = 89
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Send'
    TabOrder = 3
    OnClick = BtnSendClick
  end
  object BtnConnect: TButton
    Left = 511
    Top = 8
    Width = 89
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Connect'
    TabOrder = 4
    OnClick = BtnConnectClick
  end
  object Label4: TLabel
    Left = 295
    Top = 400
    Width = 62
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Your Name:'
  end
  object EditName: TEdit
    Left = 363
    Top = 397
    Width = 142
    Height = 23
    Anchors = [akLeft, akBottom]
    TabOrder = 5
    Text = 'User1'
  end
end
