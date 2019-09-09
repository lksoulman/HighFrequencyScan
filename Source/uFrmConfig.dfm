object frmConfig: TfrmConfig
  Left = 0
  Top = 0
  Margins.Left = 10
  Margins.Right = 10
  BorderStyle = bsDialog
  Caption = #21442#25968#37197#32622
  ClientHeight = 513
  ClientWidth = 557
  Color = clBtnFace
  Font.Charset = GB2312_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #26032#23435#20307
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 12
  object lbDBDescription: TLabel
    Left = 81
    Top = 82
    Width = 105
    Height = 12
    Caption = 'lbDBDescription'
    Font.Charset = GB2312_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = #26032#23435#20307
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label1: TLabel
    Left = 27
    Top = 82
    Width = 48
    Height = 12
    Caption = #25968#25454#24211#65306
  end
  object Label2: TLabel
    Left = 150
    Top = 24
    Width = 60
    Height = 12
    Caption = #24191#25773#31471#21475#21495
  end
  object Label3: TLabel
    Left = 27
    Top = 54
    Width = 168
    Height = 12
    Caption = #33258#21160#21024#38500'            '#22825#21069#25968#25454
  end
  object RzDialogButtons1: TRzDialogButtons
    Left = 0
    Top = 477
    Width = 557
    TabOrder = 4
    ExplicitWidth = 579
  end
  object btnDBSet: TButton
    Left = 261
    Top = 77
    Width = 140
    Height = 25
    Caption = #26356#25913#25968#25454#24211#38142#25509
    TabOrder = 0
    OnClick = btnDBSetClick
  end
  object chkBroadcast: TRzCheckBox
    Left = 27
    Top = 23
    Width = 91
    Height = 15
    Caption = #24320#21551#26412#26426#24191#25773
    State = cbUnchecked
    TabOrder = 2
    WordWrap = True
  end
  object edBroadcastPort: TRzSpinEdit
    Left = 216
    Top = 21
    Width = 65
    Height = 20
    Max = 65536.000000000000000000
    Min = 1.000000000000000000
    Value = 9963.000000000000000000
    FlatButtons = True
    TabOrder = 1
  end
  object edAutoRemoveDays: TRzSpinEdit
    Left = 85
    Top = 51
    Width = 52
    Height = 20
    Max = 300.000000000000000000
    FlatButtons = True
    TabOrder = 3
  end
  object RzPageControl1: TRzPageControl
    AlignWithMargins = True
    Left = 3
    Top = 108
    Width = 551
    Height = 366
    Hint = ''
    ActivePage = TabSheet3
    Align = alBottom
    TabIndex = 1
    TabOrder = 5
    ExplicitWidth = 573
    FixedDimension = 18
    object TabSheet2: TRzTabSheet
      Caption = #25991#20214#21015#34920
      ExplicitWidth = 569
      object lvFilelist: TRzListView
        AlignWithMargins = True
        Left = 5
        Top = 5
        Width = 537
        Height = 336
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Align = alClient
        Columns = <
          item
            Caption = #36335#24452
            MinWidth = 260
            Width = 260
          end
          item
            Caption = #21551#21160#26102#38388
            MinWidth = 60
            Width = 80
          end
          item
            Caption = #32467#26463#26102#38388
            MinWidth = 60
            Width = 80
          end
          item
            Caption = #20999#29255#38388#38548'('#20998')'
            MinWidth = 100
            Width = 100
          end>
        GridLines = True
        PopupMenu = PopupMenu1
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnDblClick = lvFilelistDblClick
        ExplicitWidth = 559
      end
    end
    object TabSheet3: TRzTabSheet
      Caption = #20854#23427#37197#32622
      ExplicitWidth = 569
      object RzGroupBox1: TRzGroupBox
        Left = 13
        Top = 216
        Width = 282
        Height = 122
        Caption = 'SMTP'#37197#32622
        TabOrder = 0
        object LabeledEdit1: TLabeledEdit
          Left = 46
          Top = 28
          Width = 124
          Height = 20
          EditLabel.Width = 24
          EditLabel.Height = 12
          EditLabel.Caption = #22320#22336
          Enabled = False
          LabelPosition = lpLeft
          TabOrder = 0
        end
        object RzSpinEdit2: TRzSpinEdit
          Left = 176
          Top = 28
          Width = 60
          Height = 20
          Max = 65536.000000000000000000
          Min = 1.000000000000000000
          Value = 25.000000000000000000
          TabOrder = 1
        end
        object LabeledEdit2: TLabeledEdit
          Left = 46
          Top = 62
          Width = 124
          Height = 20
          EditLabel.Width = 36
          EditLabel.Height = 12
          EditLabel.Caption = #29992#25143#21517
          Enabled = False
          LabelPosition = lpLeft
          TabOrder = 2
        end
        object LabeledEdit3: TLabeledEdit
          Left = 46
          Top = 94
          Width = 124
          Height = 20
          EditLabel.Width = 24
          EditLabel.Height = 12
          EditLabel.Caption = #23494#30721
          Enabled = False
          LabelPosition = lpLeft
          TabOrder = 3
        end
      end
      object RzGroupBox2: TRzGroupBox
        Left = 301
        Top = 10
        Width = 228
        Height = 328
        Caption = #25554#20214#37197#32622
        TabOrder = 1
        object chkPlugins: TRzCheckList
          AlignWithMargins = True
          Left = 11
          Top = 18
          Width = 206
          Height = 304
          Margins.Left = 10
          Margins.Top = 5
          Margins.Right = 10
          Margins.Bottom = 5
          Items.Strings = (
            #25968#25454#24211#33853#22320
            'CSV'#25991#20214#33853#22320
            #20108#36827#21046#25991#20214#33853#22320
            'SuNing-TXT'#25991#20214#33853#22320
            #30417#25511#25253#35686#25554#20214
            'Kafka')
          Items.ItemEnabled = (
            True
            True
            True
            True
            True
            True)
          Items.ItemState = (
            0
            0
            0
            0
            0
            0)
          Align = alClient
          ItemHeight = 17
          TabOrder = 0
          ExplicitWidth = 518
          ExplicitHeight = 89
        end
      end
      object RzGroupBox3: TRzGroupBox
        Left = 13
        Top = 10
        Width = 282
        Height = 200
        Caption = #25253#35686#37197#32622
        TabOrder = 2
        object Label4: TLabel
          Left = 8
          Top = 144
          Width = 84
          Height = 12
          Caption = #33258#23450#20041#28040#24687#27169#26495
        end
        object LabeledEdit4: TLabeledEdit
          Left = 8
          Top = 32
          Width = 265
          Height = 20
          EditLabel.Width = 54
          EditLabel.Height = 12
          EditLabel.Caption = #33258#23450#20041'URL'
          TabOrder = 0
        end
        object LabeledEdit5: TLabeledEdit
          Left = 8
          Top = 72
          Width = 265
          Height = 20
          EditLabel.Width = 54
          EditLabel.Height = 12
          EditLabel.Caption = #38025#38025'TOKEN'
          TabOrder = 1
        end
        object Memo1: TMemo
          Left = 8
          Top = 162
          Width = 265
          Height = 31
          Enabled = False
          Lines.Strings = (
            #26242#19981#25903#25345)
          TabOrder = 3
        end
        object LabeledEdit6: TLabeledEdit
          Left = 8
          Top = 118
          Width = 265
          Height = 20
          EditLabel.Width = 54
          EditLabel.Height = 12
          EditLabel.Caption = #24494#20449'TOKEN'
          TabOrder = 2
        end
      end
    end
  end
  object PopupMenu1: TPopupMenu
    AutoHotkeys = maManual
    Left = 392
    Top = 272
    object miAddFile: TMenuItem
      Caption = #26032#22686#25991#20214
      OnClick = miAddFileClick
    end
    object miRemoveFile: TMenuItem
      Caption = #31227#38500#25991#20214
    end
  end
end
