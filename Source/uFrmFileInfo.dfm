object frmFileInfo: TfrmFileInfo
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #25991#20214#37197#32622
  ClientHeight = 400
  ClientWidth = 433
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCloseQuery = FormCloseQuery
  PixelsPerInch = 96
  TextHeight = 13
  object RzDialogButtons1: TRzDialogButtons
    Left = 0
    Top = 364
    Width = 433
    HotTrack = True
    OnClickOk = RzDialogButtons1ClickOk
    OnClickCancel = RzDialogButtons1ClickCancel
    TabOrder = 2
    ExplicitTop = 187
    ExplicitWidth = 387
  end
  object RzGroupBox1: TRzGroupBox
    Left = 15
    Top = 8
    Width = 394
    Height = 161
    Caption = #25195#25551#37197#32622
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 59
      Width = 72
      Height = 13
      Caption = #25195#25551#36215#22987#26102#38388
    end
    object Label2: TLabel
      Left = 144
      Top = 59
      Width = 72
      Height = 13
      Caption = #25195#25551#32467#26463#26102#38388
    end
    object Label3: TLabel
      Left = 16
      Top = 105
      Width = 156
      Height = 13
      Caption = #33258#21160#20999#29255#38388#38548#65288#21333#20301#65306#20998#38047#65289
    end
    object btnPickFile: TButton
      Left = 337
      Top = 30
      Width = 42
      Height = 25
      Caption = '...'
      TabOrder = 0
      OnClick = btnPickFileClick
    end
    object dtEnd: TDateTimePicker
      Left = 144
      Top = 78
      Width = 90
      Height = 21
      Date = 42754.353626701390000000
      Time = 42754.353626701390000000
      Kind = dtkTime
      TabOrder = 3
    end
    object dtStart: TDateTimePicker
      Left = 16
      Top = 78
      Width = 90
      Height = 21
      Date = 42754.353626701390000000
      Time = 42754.353626701390000000
      Kind = dtkTime
      TabOrder = 2
    end
    object edFileInfo: TLabeledEdit
      Left = 16
      Top = 32
      Width = 315
      Height = 21
      EditLabel.Width = 36
      EditLabel.Height = 13
      EditLabel.Caption = #25991#20214#21517
      TabOrder = 1
    end
    object edSplitMintue: TSpinEdit
      Left = 16
      Top = 124
      Width = 90
      Height = 22
      MaxValue = 60
      MinValue = 0
      TabOrder = 4
      Value = 0
    end
  end
  object RzGroupBox2: TRzGroupBox
    Left = 15
    Top = 183
    Width = 394
    Height = 175
    Caption = #30417#25511
    TabOrder = 1
    object Label4: TLabel
      Left = 126
      Top = 28
      Width = 108
      Height = 13
      Caption = #26368#22823#24310#26102#26356#26032#65288#31186#65289
    end
    object Label5: TLabel
      Left = 16
      Top = 58
      Width = 188
      Height = 13
      Caption = #30417#25511#26102#27573#19968#65306'                                    ~'
    end
    object Label6: TLabel
      Left = 16
      Top = 88
      Width = 188
      Height = 13
      Caption = #30417#25511#26102#27573#20108#65306'                                    ~'
    end
    object cbkMonitorEnable: TRzCheckBox
      Left = 16
      Top = 27
      Width = 67
      Height = 15
      Caption = #24320#21551#30417#25511
      State = cbUnchecked
      TabOrder = 1
      WordWrap = True
      OnClick = cbkMonitorEnableClick
    end
    object edMonitorCodes: TLabeledEdit
      Left = 16
      Top = 137
      Width = 356
      Height = 21
      EditLabel.Width = 240
      EditLabel.Height = 13
      EditLabel.Caption = #30417#25511#20195#30721#21015#34920#65288#22810#20010#20195#30721#65292#35831#20351#29992#36887#21495#20998#38548#65289
      TabOrder = 6
    end
    object edMonitorInterval: TSpinEdit
      Left = 240
      Top = 23
      Width = 57
      Height = 22
      MaxValue = 120
      MinValue = 3
      TabOrder = 0
      Value = 0
    end
    object dtMTRange1Start: TDateTimePicker
      Left = 112
      Top = 54
      Width = 73
      Height = 21
      Date = 42754.353626701390000000
      Time = 42754.353626701390000000
      Kind = dtkTime
      TabOrder = 2
    end
    object dtMTRange1End: TDateTimePicker
      Left = 224
      Top = 54
      Width = 73
      Height = 21
      Date = 42754.353626701390000000
      Time = 42754.353626701390000000
      Kind = dtkTime
      TabOrder = 3
    end
    object dtMTRange2Start: TDateTimePicker
      Left = 112
      Top = 84
      Width = 73
      Height = 21
      Date = 42754.353626701390000000
      Time = 42754.353626701390000000
      Kind = dtkTime
      TabOrder = 4
    end
    object dtMTRange2End: TDateTimePicker
      Left = 224
      Top = 84
      Width = 73
      Height = 21
      Date = 42754.353626701390000000
      Time = 42754.353626701390000000
      Kind = dtkTime
      TabOrder = 5
    end
  end
  object FileOpenDialog1: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <>
    Options = []
    Left = 288
    Top = 88
  end
end
