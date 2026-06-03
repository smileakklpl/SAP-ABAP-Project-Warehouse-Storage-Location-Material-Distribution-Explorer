*&---------------------------------------------------------------------*
*& Report Z01_WAREHOUSE
*&---------------------------------------------------------------------*
*& 3-level interactive WM report (OO ABAP, WRITE-based output)
*&---------------------------------------------------------------------*
REPORT Z01_WAREHOUSE LINE-SIZE 255.

DATA selection_lgnum TYPE lqua-lgnum.
DATA selection_matnr TYPE lqua-matnr.

" Dialog / Screen config and runtime variables (for Screen Painter binding)
CONSTANTS: c_dialog_screen   TYPE i VALUE 9000,
           c_transfer_screen TYPE i VALUE 9001.

DATA: dialog_matnr    TYPE lqua-matnr,
      dialog_werks    TYPE lqua-werks,
      dialog_lgnum    TYPE lqua-lgnum,
      dialog_dst_lgtyp TYPE lqua-lgtyp,
      dialog_dst_lgpla TYPE lqua-lgpla,
      dialog_src_lgtyp TYPE lqua-lgtyp,
      dialog_src_lgpla TYPE lqua-lgpla,
      dialog_qty      TYPE string,
  ok_code         TYPE sy-ucomm,
      gv_new_tanum    TYPE ltak-tanum.



SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE g_titl.
SELECTION-SCREEN COMMENT /1(79) g_cmt1.
SELECT-OPTIONS:
  s_lgnum FOR selection_lgnum,
  s_matnr FOR selection_matnr.
SELECTION-SCREEN COMMENT /1(79) g_cmt2.
SELECTION-SCREEN END OF BLOCK b01.

DATA gv_current_level TYPE i.
DATA gv_is_data_line TYPE abap_bool.
DATA gv_in_transfer_log TYPE abap_bool.
DATA gv_matnr TYPE lqua-matnr.
DATA gv_werks TYPE lqua-werks.
DATA gv_lgnum TYPE lqua-lgnum.
DATA gv_lgtyp TYPE lqua-lgtyp.
DATA gv_lgpla TYPE lqua-lgpla.
DATA gv_verme TYPE lqua-verme.

CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS run.
    METHODS on_line_selection.
    METHODS show_transfer_log
      IMPORTING
        iv_tanum TYPE ltak-tanum.
    METHODS create_transfer_order
      IMPORTING
        matnr         TYPE lqua-matnr
        werks         TYPE lqua-werks
        lgnum         TYPE lqua-lgnum
        src_lgtyp     TYPE lqua-lgtyp
        src_lgpla     TYPE lqua-lgpla
        dst_lgtyp     TYPE lqua-lgtyp
        dst_lgpla     TYPE lqua-lgpla
        qty           TYPE lqua-verme
      RETURNING VALUE(rv_tanum) TYPE ltak-tanum.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_level1,
             matnr      TYPE lqua-matnr,
             maktx      TYPE makt-maktx,
             werks      TYPE lqua-werks,
             total_verme TYPE lqua-verme,
             minbe      TYPE marc-minbe,
           END OF ty_level1.

    TYPES ty_t_level1 TYPE STANDARD TABLE OF ty_level1 WITH EMPTY KEY.

    TYPES: BEGIN OF ty_level2,
             matnr TYPE lqua-matnr,
             lgnum TYPE lqua-lgnum,
             lgtyp TYPE lqua-lgtyp,
             lgpla TYPE lqua-lgpla,
             verme TYPE lqua-verme,
           END OF ty_level2.

    TYPES ty_t_level2 TYPE STANDARD TABLE OF ty_level2 WITH EMPTY KEY.

    TYPES: BEGIN OF ty_level3,
             lgnum TYPE lagp-lgnum,
             lgtyp TYPE lagp-lgtyp,
             lgpla TYPE lagp-lgpla,
             skzue TYPE lagp-skzue,
             mgewi TYPE lagp-mgewi,
             lgewi TYPE lagp-lgewi,
             gewei TYPE lagp-gewei,
           END OF ty_level3.

    TYPES: BEGIN OF ty_level3_quant,
             matnr TYPE lqua-matnr,
             werks TYPE lqua-werks,
             verme TYPE lqua-verme,
           END OF ty_level3_quant.

    TYPES ty_t_level3_quant TYPE STANDARD TABLE OF ty_level3_quant WITH EMPTY KEY.

    METHODS get_level1_data
      RETURNING VALUE(result) TYPE ty_t_level1.
    METHODS get_level2_data
      IMPORTING
        matnr         TYPE lqua-matnr
        werks         TYPE lqua-werks
      RETURNING VALUE(result) TYPE ty_t_level2.
    METHODS get_level3_data
      IMPORTING
        lgnum         TYPE lagp-lgnum
        lgtyp         TYPE lagp-lgtyp
        lgpla         TYPE lagp-lgpla
      RETURNING VALUE(result) TYPE ty_level3.
    METHODS get_level3_quant_data
      IMPORTING
        lgnum         TYPE lagp-lgnum
        lgtyp         TYPE lagp-lgtyp
        lgpla         TYPE lagp-lgpla
      RETURNING VALUE(result) TYPE ty_t_level3_quant.

    METHODS show_level1.
    METHODS show_level2
      IMPORTING
        matnr         TYPE lqua-matnr
        werks         TYPE lqua-werks.
    METHODS show_level3
      IMPORTING
        lgnum         TYPE lagp-lgnum
        lgtyp         TYPE lagp-lgtyp
        lgpla         TYPE lagp-lgpla.
    METHODS explain_level2_no_data
      IMPORTING
        matnr         TYPE lqua-matnr
        werks         TYPE lqua-werks.
    METHODS run_replenishment_flow
      IMPORTING
        matnr         TYPE lqua-matnr
        werks         TYPE lqua-werks
        lgnum         TYPE lqua-lgnum
        dst_lgtyp     TYPE lqua-lgtyp
        dst_lgpla     TYPE lqua-lgpla
        dst_verme     TYPE lqua-verme.
    METHODS get_suggested_source_bin
      IMPORTING
        matnr         TYPE lqua-matnr
        werks         TYPE lqua-werks
        lgnum         TYPE lqua-lgnum
        dst_lgtyp     TYPE lqua-lgtyp
        dst_lgpla     TYPE lqua-lgpla
      EXPORTING
        src_lgtyp     TYPE lqua-lgtyp
        src_lgpla     TYPE lqua-lgpla
        src_verme     TYPE lqua-verme.
    METHODS generate_tanum
      IMPORTING
        lgnum         TYPE ltak-lgnum
      RETURNING VALUE(rv_tanum) TYPE ltak-tanum.
    " create_transfer_order moved to PUBLIC so dialog wrapper can call it

    " Class-local attributes for other logic
    DATA gv_dialog_helper TYPE i.

    DATA level1_data TYPE ty_t_level1.
    DATA level2_data TYPE ty_t_level2.
    DATA level3_data TYPE ty_level3.
    DATA level1_row TYPE ty_level1.
    DATA level2_row TYPE ty_level2.
    DATA level3_row TYPE ty_level3.
ENDCLASS.

CLASS lcl_report DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS initialize.
    CLASS-METHODS start.
    CLASS-METHODS on_line_selection.
    CLASS-METHODS show_transfer_log
      IMPORTING
        iv_tanum TYPE ltak-tanum.
    CLASS-METHODS dialog_submit
      RETURNING VALUE(rv_tanum) TYPE ltak-tanum.

  PRIVATE SECTION.
    CLASS-DATA app TYPE REF TO lcl_app.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD run.
    show_level1( ).
  ENDMETHOD.

  METHOD on_line_selection.
    IF gv_in_transfer_log = abap_true.
      MESSAGE '目前顯示的是補貨追蹤表，請使用返回鍵離開' TYPE 'S'.
      RETURN.
    ENDIF.

    IF gv_is_data_line <> abap_true.
      MESSAGE '請雙擊資料列，不要點標題或空白列' TYPE 'S'.
      RETURN.
    ENDIF.

    CASE gv_current_level.
      WHEN 1.
        show_level2(
          matnr = gv_matnr
          werks = gv_werks ).
      WHEN 2.
        IF gv_verme < 10.
          run_replenishment_flow(
            matnr = gv_matnr
            werks = gv_werks
            lgnum = gv_lgnum
            dst_lgtyp = gv_lgtyp
            dst_lgpla = gv_lgpla
            dst_verme = gv_verme ).
        ELSE.
          show_level3(
            lgnum = gv_lgnum
            lgtyp = gv_lgtyp
            lgpla = gv_lgpla ).
        ENDIF.
      WHEN 3.
        MESSAGE '已達最底層，無法繼續展開' TYPE 'S'.
      WHEN OTHERS.
        MESSAGE '無法判斷目前層級' TYPE 'S'.
    ENDCASE.
  ENDMETHOD.

  METHOD explain_level2_no_data.
    SELECT COUNT( * )
      FROM lqua
      WHERE matnr = @matnr
        AND werks = @werks
        AND verme >= 0
        AND lgnum IN @s_lgnum
      INTO @DATA(exact_count).

    SELECT COUNT( * )
      FROM lqua
      WHERE matnr = @matnr
        AND werks = @werks
        AND verme >= 0
      INTO @DATA(no_lgnum_count).

    SELECT COUNT( * )
      FROM lqua
      WHERE matnr = @matnr
        AND verme >= 0
      INTO @DATA(matnr_only_count).

    WRITE: / '診斷資訊：'.
    IF matnr_only_count = 0.
      WRITE: / '- 資料缺失：LQUA 中此 MATNR 不存在 VERME >= 0 的庫存資料'.
    ELSEIF no_lgnum_count = 0.
      WRITE: / '- 欄位鍵值不一致：MATNR 有庫存，但此 WERKS 條件查不到資料'.
      WRITE: / '- 請檢查 Level 1 傳入的 WERKS 是否正確'.
    ELSEIF exact_count = 0.
      WRITE: / '- 篩選條件排除：MATNR+WERKS 有資料，但被 S_LGNUM 條件排除'.
    ELSE.
      WRITE: / '- 查詢有結果，請重新雙擊資料列再試一次'.
    ENDIF.

    WRITE: / '- 目前鍵值 MATNR=', matnr, 'WERKS=', werks.
    WRITE: / '- 計數 exact=', exact_count,
          ' no_lgnum=', no_lgnum_count,
          ' matnr_only=', matnr_only_count.
  ENDMETHOD.

  METHOD get_level1_data.
    SELECT
      lqua~matnr,
      COALESCE( makt~maktx, ' ' )         AS maktx,
      lqua~werks,
      SUM( lqua~verme )                   AS total_verme,
      COALESCE( marc~minbe, 0 )           AS minbe
      FROM lqua
      LEFT OUTER JOIN makt
        ON makt~matnr = lqua~matnr
       AND makt~spras = @sy-langu
      LEFT OUTER JOIN marc
        ON marc~matnr = lqua~matnr
       AND marc~werks = lqua~werks
      WHERE lqua~verme >= 0
        AND lqua~lgnum IN @s_lgnum
        AND lqua~matnr IN @s_matnr
      GROUP BY
        lqua~matnr,
        lqua~werks,
        makt~maktx,
        marc~minbe
      ORDER BY
        lqua~matnr,
        lqua~werks
      INTO TABLE @result.
  ENDMETHOD.

  METHOD get_level2_data.
    SELECT
      matnr,
      lgnum,
      lgtyp,
      lgpla,
      verme
      FROM lqua
      WHERE matnr = @matnr
        AND werks = @werks
        AND verme >= 0
        AND lgnum IN @s_lgnum
      ORDER BY lgtyp, lgpla
      INTO TABLE @result.
  ENDMETHOD.

  METHOD get_level3_data.
    SELECT SINGLE
      lgnum,
      lgtyp,
      lgpla,
      skzue,
      mgewi,
      lgewi,
      gewei
      FROM lagp
      WHERE lgnum = @lgnum
        AND lgtyp = @lgtyp
        AND lgpla = @lgpla
      INTO @result.
  ENDMETHOD.

  METHOD get_level3_quant_data.
    SELECT
      matnr,
      werks,
      verme
      FROM lqua
      WHERE lgnum = @lgnum
        AND lgtyp = @lgtyp
        AND lgpla = @lgpla
        AND verme >= 0
      ORDER BY matnr
      INTO TABLE @result.
  ENDMETHOD.

  METHOD show_level1.
    level1_data = get_level1_data( ).
    gv_is_data_line = abap_false.
    CLEAR: gv_matnr, gv_werks, gv_lgnum, gv_lgtyp, gv_lgpla.

    NEW-PAGE.
    FORMAT RESET.

    FORMAT COLOR COL_HEADING INTENSIFIED ON.
    WRITE: / 'WM 庫存儀表板 - 第一層 物料總量總覽'.
    FORMAT RESET.
    WRITE: / '操作提示：雙擊任一資料列可展開到第二層（儲位分布明細）'.
    WRITE: / '圖例：紅色列 = 總可用庫存低於 10，需優先補貨'.
    ULINE AT /2(160).

    IF level1_data IS INITIAL.
      WRITE: / '查無符合條件資料'.
      RETURN.
    ENDIF.

    DATA(level1_total_rows) = lines( level1_data ).
    DATA(level1_low_rows) = 0.

    LOOP AT level1_data INTO level1_row.
      IF level1_row-total_verme < 10.
        level1_low_rows = level1_low_rows + 1.
      ENDIF.
    ENDLOOP.

    WRITE: / '統計：總筆數 =', level1_total_rows,
         '，低庫存警示筆數 =', level1_low_rows,
         '（門檻 < 10）'.
    ULINE AT /2(160).

    FORMAT COLOR COL_HEADING.
    WRITE: /2 '|物料代碼(MATNR)',
       24 '|物料說明(MAKTX)',
       65 '|工廠(WERKS)',
       80 '|總可用庫存(VERME加總)',
       115 '|安全庫存(MINBE)',
       160 '|'.
    FORMAT RESET.
    ULINE AT /2(160).

    LOOP AT level1_data INTO level1_row.
      DATA(minbe_text) = ||.
      IF level1_row-minbe = 0.
        minbe_text = '初始欄位未設定'.
      ELSE.
        minbe_text = |{ level1_row-minbe }|.
      ENDIF.

      IF level1_row-total_verme < 10.
        FORMAT COLOR COL_NEGATIVE.
      ELSE.
        FORMAT RESET.
      ENDIF.

      WRITE: /2 '|', level1_row-matnr,
        24 '|', level1_row-maktx,
        65 '|', level1_row-werks,
        80 '|', level1_row-total_verme,
        115 '|', minbe_text,
        160 '|'.

      gv_current_level = 1.
      gv_matnr = level1_row-matnr.
      gv_werks = level1_row-werks.
      gv_is_data_line = abap_true.
      HIDE: gv_current_level, gv_matnr, gv_werks, gv_is_data_line.
    ENDLOOP.

    FORMAT RESET.
    ULINE AT /2(160).
  ENDMETHOD.

  METHOD show_level2.
    level2_data = get_level2_data(
      matnr = matnr
      werks = werks ).
    DATA(has_low_stock) = abap_false.
    DATA(level2_total_rows) = lines( level2_data ).
    DATA(level2_low_rows) = 0.
    gv_is_data_line = abap_false.
    CLEAR: gv_lgnum, gv_lgtyp, gv_lgpla, gv_verme.

    NEW-PAGE.
    FORMAT RESET.

    FORMAT COLOR COL_HEADING INTENSIFIED ON.
    WRITE: / 'WM 庫存儀表板 - 第二層 儲位分布明細'.
    FORMAT RESET.
    WRITE: / '操作提示：雙擊低庫存列(<10)可直接建立補貨任務；其餘列展開第三層'.
    WRITE: / '圖例：紅色列 = 儲位可用庫存低於 10，需優先補貨'.
    WRITE: / '物料代碼(MATNR):', matnr, 42 '工廠(WERKS):', werks.
    ULINE AT /2(121).
    FORMAT COLOR COL_HEADING.
    WRITE: /2 '|物料代碼(MATNR)',
       24 '|倉庫號碼(LGNUM)',
       44 '|倉儲類型(LGTYP)',
       82 '|儲位(LGPLA)',
       100 '|可用庫存(VERME)',
       122 '|'.
    FORMAT RESET.
    ULINE AT /2(121).

    IF level2_data IS INITIAL.
      WRITE: / '查無該物料在此工廠的儲位資料'.
      explain_level2_no_data(
        matnr = matnr
        werks = werks ).
      RETURN.
    ENDIF.

    LOOP AT level2_data INTO level2_row.
      DATA(lgtyp_key) = level2_row-lgtyp.
      DATA(lgtyp_text) = ||.
      DATA(lgtyp_display) = ||.

      SHIFT lgtyp_key LEFT DELETING LEADING space.
      IF strlen( lgtyp_key ) = 1.
        CONCATENATE '00' lgtyp_key INTO lgtyp_key.
      ELSEIF strlen( lgtyp_key ) = 2.
        CONCATENATE '0' lgtyp_key INTO lgtyp_key.
      ENDIF.

      CASE lgtyp_key.
        WHEN '001'.
          lgtyp_text = 'Shelf Storage'.
        WHEN '002'.
          lgtyp_text = 'Pallet Storage'.
        WHEN '003'.
          lgtyp_text = 'GR Area External Receipts'.
        WHEN '004'.
          lgtyp_text = 'Shipping Area Deliveries'.
        WHEN '005'.
          lgtyp_text = 'Stock Transfers (Plant)'.
        WHEN '999'.
          lgtyp_text = 'Differences'.
        WHEN OTHERS.
          lgtyp_text = ''.
      ENDCASE.

      IF lgtyp_text IS INITIAL.
        lgtyp_display = |Undefined/Other ({ lgtyp_key })|.
      ELSE.
        lgtyp_display = |{ lgtyp_text } ({ lgtyp_key })|.
      ENDIF.

      IF strlen( lgtyp_display ) > 35.
        lgtyp_display = |{ lgtyp_display(32) }...|.
      ENDIF.

      IF level2_row-verme < 10.
        FORMAT COLOR COL_NEGATIVE.
        has_low_stock = abap_true.
        level2_low_rows = level2_low_rows + 1.
      ELSE.
        FORMAT RESET.
      ENDIF.

      WRITE: /2 '|', level2_row-matnr,
        24 '|', level2_row-lgnum,
        44 '|', lgtyp_display,
        82 '|', level2_row-lgpla,
        100 '|', level2_row-verme,
        122 '|'.

      gv_current_level = 2.
      gv_matnr = level2_row-matnr.
      gv_werks = werks.
      gv_lgnum = level2_row-lgnum.
      gv_lgtyp = level2_row-lgtyp.
      gv_lgpla = level2_row-lgpla.
      gv_verme = level2_row-verme.
      gv_is_data_line = abap_true.
      HIDE: gv_current_level, gv_matnr, gv_werks, gv_lgnum, gv_lgtyp, gv_lgpla, gv_verme, gv_is_data_line.
    ENDLOOP.

    FORMAT RESET.
    ULINE AT /2(121).
    WRITE: / '統計：總筆數 =', level2_total_rows,
         '，低庫存警示筆數 =', level2_low_rows,
         '（門檻 < 10）'.
    IF has_low_stock = abap_true.
      WRITE: /.
      WRITE: / '提醒: 庫存即將見底，請及時補貨。'.
    ENDIF.
  ENDMETHOD.

  METHOD show_level3.
    level3_data = get_level3_data(
      lgnum = lgnum
      lgtyp = lgtyp
      lgpla = lgpla ).
    DATA(level3_quants) = get_level3_quant_data(
      lgnum = lgnum
      lgtyp = lgtyp
      lgpla = lgpla ).
    gv_is_data_line = abap_false.
    CLEAR: gv_lgnum, gv_lgtyp, gv_lgpla.

    NEW-PAGE.
    FORMAT RESET.

    FORMAT COLOR COL_HEADING INTENSIFIED ON.
    WRITE: / 'WM 庫存儀表板 - 第三層 儲位主檔細節'.
    FORMAT RESET.
    WRITE: / '操作提示：已是最底層；再次雙擊僅顯示提示訊息'.
    WRITE: / '說明：初始欄位未設定 = 主檔欄位目前未維護'.
    ULINE AT /2(170).
    FORMAT COLOR COL_HEADING.
    WRITE: /2 '|倉庫號碼(LGNUM)',
       22 '|倉儲類型(LGTYP)',
       55 '|儲位(LGPLA)',
       70 '|入庫凍結狀態(SKZUE)',
       110 '|最大容量重量(MGEWI)',
       145 '|已使用重量(LGEWI)',
       170 '|'.
    DATA(lgtyp_key) = level3_row-lgtyp.
    DATA(lgtyp_text) = ||.
    DATA(lgtyp_display) = ||.
    DATA(skzue_text) = ||.
    DATA(max_weight_text) = ||.
    DATA(occupied_weight_text) = ||.

    SHIFT lgtyp_key LEFT DELETING LEADING space.
    IF strlen( lgtyp_key ) = 1.
      CONCATENATE '00' lgtyp_key INTO lgtyp_key.
    ELSEIF strlen( lgtyp_key ) = 2.
      CONCATENATE '0' lgtyp_key INTO lgtyp_key.
    ENDIF.

    CASE lgtyp_key.
      WHEN '001'.
        lgtyp_text = 'Shelf Storage'.
      WHEN '002'.
        lgtyp_text = 'Pallet Storage'.
      WHEN '003'.
        lgtyp_text = 'GR Area Ext Rcpt'.
      WHEN '004'.
        lgtyp_text = 'Ship Area Deliv'.
      WHEN '005'.
        lgtyp_text = 'Stock Transfers'.
      WHEN '999'.
        lgtyp_text = 'Differences'.
      WHEN OTHERS.
        lgtyp_text = ''.
    ENDCASE.

    IF lgtyp_text IS INITIAL.
      lgtyp_display = |Undefined/Other ({ lgtyp_key })|.
    ELSE.
      lgtyp_display = |{ lgtyp_text } ({ lgtyp_key })|.
    ENDIF.

    IF strlen( lgtyp_display ) > 35.
      lgtyp_display = |{ lgtyp_display(32) }...|.
    ENDIF.

    IF level3_row-skzue IS INITIAL.
      skzue_text = '初始欄位未設定'.
    ELSE.
      skzue_text = level3_row-skzue.
    ENDIF.

    IF level3_row-lgewi = 0.
      max_weight_text = '初始欄位未設定'.
    ELSE.
      IF level3_row-gewei IS INITIAL.
        max_weight_text = |{ level3_row-lgewi }|.
      ELSE.
        max_weight_text = |{ level3_row-lgewi } { level3_row-gewei }|.
      ENDIF.
    ENDIF.

    IF level3_row-mgewi = 0.
      occupied_weight_text = '初始欄位未設定'.
    ELSE.
      IF level3_row-gewei IS INITIAL.
        occupied_weight_text = |{ level3_row-mgewi }|.
      ELSE.
        occupied_weight_text = |{ level3_row-mgewi } { level3_row-gewei }|.
      ENDIF.
    ENDIF.

    WRITE: /2 '|', level3_row-lgnum,
      22 '|', lgtyp_display,
      55 '|', level3_row-lgpla,
      70 '|', skzue_text,
      110 '|', max_weight_text,
      145 '|', occupied_weight_text,
      170 '|'.

    ULINE AT /2(170).

    WRITE: /.
    FORMAT COLOR COL_HEADING INTENSIFIED ON.
    WRITE: / '關聯 Traversal A：此儲位庫存明細（LQUA）'.
    FORMAT RESET.
    ULINE AT /2(121).
    FORMAT COLOR COL_HEADING.
    WRITE: /2 '|物料代碼(MATNR)',
       24 '|工廠(WERKS)',
       45 '|可用庫存(VERME)',
       122 '|'.
    FORMAT RESET.
    ULINE AT /2(121).

    IF level3_quants IS INITIAL.
      WRITE: / '此儲位無關聯庫存明細資料'.
    ELSE.
      LOOP AT level3_quants INTO DATA(level3_quant_row).
        WRITE: /2 '|', level3_quant_row-matnr,
          24 '|', level3_quant_row-werks,
          45 '|', level3_quant_row-verme,
          122 '|'.
      ENDLOOP.
    ENDIF.
    ULINE AT /2(121).

    gv_current_level = 3.
    gv_lgnum = level3_row-lgnum.
    gv_lgtyp = level3_row-lgtyp.
    gv_lgpla = level3_row-lgpla.
    gv_verme = 0.
    gv_is_data_line = abap_true.
    HIDE: gv_current_level, gv_lgnum, gv_lgtyp, gv_lgpla, gv_verme, gv_is_data_line.
  ENDMETHOD.

  METHOD get_suggested_source_bin.
    CLEAR: src_lgtyp, src_lgpla, src_verme.

    DATA lt_candidates TYPE STANDARD TABLE OF ty_level2 WITH EMPTY KEY.

    SELECT matnr, lgnum, lgtyp, lgpla, verme
      FROM lqua
      WHERE matnr = @matnr
        AND werks = @werks
        AND lgnum = @lgnum
        AND NOT ( lgtyp = @dst_lgtyp AND lgpla = @dst_lgpla )
        AND verme > 0
      ORDER BY verme DESCENDING
      INTO TABLE @lt_candidates.

    READ TABLE lt_candidates INTO DATA(ls_candidate) INDEX 1.
    IF sy-subrc = 0.
      src_lgtyp = ls_candidate-lgtyp.
      src_lgpla = ls_candidate-lgpla.
      src_verme = ls_candidate-verme.
    ENDIF.
  ENDMETHOD.

  METHOD generate_tanum.
    CONSTANTS c_nr_object TYPE inri-object VALUE 'ZWM_TANUM'.
    CONSTANTS c_nr_range  TYPE inri-nrrangenr VALUE '01'.

    rv_tanum = 0.

    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = c_nr_range
        object      = c_nr_object
      IMPORTING
        number      = rv_tanum
      EXCEPTIONS
        OTHERS      = 1.

    IF sy-subrc <> 0 OR rv_tanum IS INITIAL.
      SELECT MAX( tanum )
        FROM ltak
        WHERE lgnum = @lgnum
        INTO @DATA(lv_max_tanum).
      rv_tanum = lv_max_tanum + 1.
      MESSAGE 'Number range 取號失敗，改用 MAX(TANUM)+1 備援機制' TYPE 'S'.
    ENDIF.
  ENDMETHOD.

  METHOD create_transfer_order.
    rv_tanum = 0.

    DATA lv_meins TYPE mara-meins.
    SELECT SINGLE meins
      FROM mara
      WHERE matnr = @matnr
      INTO @lv_meins.

    DATA lv_tanum TYPE ltak-tanum.
    lv_tanum = generate_tanum( lgnum = lgnum ).

    IF lv_tanum IS INITIAL.
      MESSAGE '無法產生 TANUM，請聯絡系統管理員' TYPE 'E'.
      RETURN.
    ENDIF.

    DATA ls_ltak TYPE ltak.
    ls_ltak-lgnum = lgnum.
    ls_ltak-tanum = lv_tanum.
    ls_ltak-bdatu = sy-datum.
    ls_ltak-bzeit = sy-uzeit.
    ls_ltak-bname = sy-uname.
    ls_ltak-noitm = 1.
    ls_ltak-trart = 'X'.

    INSERT ltak FROM ls_ltak.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      MESSAGE 'LTAK 寫入失敗，補貨任務未建立' TYPE 'E'.
      RETURN.
    ENDIF.

    DATA ls_ltap TYPE ltap.
    ls_ltap-lgnum = lgnum.
    ls_ltap-tanum = lv_tanum.
    ls_ltap-tapos = 1.
    ls_ltap-matnr = matnr.
    ls_ltap-werks = werks.
    ls_ltap-vltyp = src_lgtyp.
    ls_ltap-vlpla = src_lgpla.
    ls_ltap-nltyp = dst_lgtyp.
    ls_ltap-nlpla = dst_lgpla.
    ls_ltap-vsola = qty.
    ls_ltap-meins = lv_meins.
    ls_ltap-altme = lv_meins.

    INSERT ltap FROM ls_ltap.
    IF sy-subrc <> 0.
      DELETE FROM ltak WHERE lgnum = @lgnum AND tanum = @lv_tanum.
      ROLLBACK WORK.
      MESSAGE 'LTAP 寫入失敗，補貨任務未建立' TYPE 'E'.
      RETURN.
    ENDIF.

    COMMIT WORK AND WAIT.
    rv_tanum = lv_tanum.
  ENDMETHOD.

  METHOD run_replenishment_flow.
    DATA lv_src_lgtyp TYPE lqua-lgtyp.
    DATA lv_src_lgpla TYPE lqua-lgpla.
    DATA lv_src_verme TYPE lqua-verme.

    get_suggested_source_bin(
      EXPORTING
        matnr = matnr
        werks = werks
        lgnum = lgnum
        dst_lgtyp = dst_lgtyp
        dst_lgpla = dst_lgpla
      IMPORTING
        src_lgtyp = lv_src_lgtyp
        src_lgpla = lv_src_lgpla
        src_verme = lv_src_verme ).

    IF lv_src_lgpla IS INITIAL.
      MESSAGE '找不到可用來源儲位，請先補充上游庫存' TYPE 'S'.
      RETURN.
    ENDIF.

    DATA lv_qty TYPE lqua-verme.
    lv_qty = 10 - dst_verme.
    IF lv_qty <= 0.
      lv_qty = 1.
    ENDIF.

    IF lv_qty > lv_src_verme.
      lv_qty = lv_src_verme.
    ENDIF.

    dialog_matnr = matnr.
    dialog_werks = werks.
    dialog_lgnum = lgnum.
    dialog_dst_lgtyp = dst_lgtyp.
    dialog_dst_lgpla = dst_lgpla.
    dialog_src_lgtyp = lv_src_lgtyp.
    dialog_src_lgpla = lv_src_lgpla.
    dialog_qty = lv_qty.

    CALL SCREEN c_dialog_screen.
  ENDMETHOD.

  METHOD show_transfer_log.
    gv_in_transfer_log = abap_true.
    gv_is_data_line = abap_false.
    CLEAR: gv_current_level, gv_matnr, gv_werks, gv_lgnum, gv_lgtyp, gv_lgpla, gv_verme.

    SELECT SINGLE
      h~tanum,
      h~lgnum,
      h~bdatu,
      h~bzeit,
      h~bname,
      p~matnr,
      p~werks,
      p~vsola,
      p~meins,
      p~vltyp,
      p~vlpla,
      p~nltyp,
      p~nlpla,
      COALESCE( k~maktx, ' ' ) AS maktx
      FROM ltak AS h
      INNER JOIN ltap AS p
        ON p~lgnum = h~lgnum
       AND p~tanum = h~tanum
      LEFT OUTER JOIN makt AS k
        ON k~matnr = p~matnr
       AND k~spras = @sy-langu
      WHERE h~tanum = @iv_tanum
      INTO @DATA(ls_log).

    IF sy-subrc <> 0.
      gv_in_transfer_log = abap_false.
      MESSAGE '查無新建補貨任務資訊' TYPE 'S'.
      RETURN.
    ENDIF.

    NEW-PAGE.
    FORMAT RESET.
    FORMAT COLOR COL_HEADING INTENSIFIED ON.
    WRITE: / 'WM 內部調撥補貨任務追蹤'.
    FORMAT RESET.
    ULINE AT /2(160).

    WRITE: / '轉帳單號(TANUM):', ls_log-tanum,
             45 '倉庫號碼(LGNUM):', ls_log-lgnum.
    WRITE: / '建立日期/時間:', ls_log-bdatu, ls_log-bzeit,
             45 '建立人員:', ls_log-bname.
    ULINE AT /2(160).

    FORMAT COLOR COL_HEADING.
    WRITE: /2 '|物料(MATNR)',
       24 '|物料說明(MAKTX)',
       70 '|工廠(WERKS)',
       84 '|數量(VSOLA)',
       102 '|來源(VLTYP/VLPLA)',
       132 '|目標(NLTYP/NLPLA)',
       160 '|' .
    FORMAT RESET.
    ULINE AT /2(160).

    DATA(lv_src_disp) = |{ ls_log-vltyp }/{ ls_log-vlpla }|.
    DATA(lv_dst_disp) = |{ ls_log-nltyp }/{ ls_log-nlpla }|.

    WRITE: /2 '|', ls_log-matnr,
      24 '|', ls_log-maktx,
      70 '|', ls_log-werks,
      84 '|', ls_log-vsola, ls_log-meins,
      102 '|', lv_src_disp,
      132 '|', lv_dst_disp,
      160 '|'.
    ULINE AT /2(160).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_report IMPLEMENTATION.
  METHOD initialize.
    g_titl = '報表查詢條件'.
    g_cmt1 = '請先輸入倉庫號碼（可多選），再輸入物料代號（可多選或區間）'.
    g_cmt2 = '提示：若不輸入物料代號，系統會依倉庫條件查詢所有符合物料'.
  ENDMETHOD.

  METHOD dialog_submit.
    rv_tanum = 0.
    DATA lv_qty TYPE lqua-verme.

    TRY.
        lv_qty = CONV lqua-verme( dialog_qty ).
      CATCH cx_sy_conversion_error.
        MESSAGE '補貨數量格式錯誤，請輸入數字' TYPE 'E'.
    ENDTRY.

    IF app IS BOUND.
      rv_tanum = app->create_transfer_order(
        matnr = dialog_matnr
        werks = dialog_werks
        lgnum = dialog_lgnum
        src_lgtyp = dialog_src_lgtyp
        src_lgpla = dialog_src_lgpla
        dst_lgtyp = dialog_dst_lgtyp
        dst_lgpla = dialog_dst_lgpla
        qty = lv_qty ).
      IF rv_tanum IS NOT INITIAL.
        gv_new_tanum = rv_tanum.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD start.
    IF app IS INITIAL.
      app = NEW lcl_app( ).
    ENDIF.

    gv_in_transfer_log = abap_false.
    app->run( ).
  ENDMETHOD.

  METHOD on_line_selection.
    IF app IS BOUND.
      app->on_line_selection( ).
    ENDIF.
  ENDMETHOD.

  METHOD show_transfer_log.
    IF app IS BOUND.
      app->show_transfer_log( iv_tanum = iv_tanum ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

INITIALIZATION.
  lcl_report=>initialize( ).

START-OF-SELECTION.
  lcl_report=>start( ).

AT LINE-SELECTION.
  IF sy-pfkey = 'ZLIST' OR gv_in_transfer_log = abap_true.
    RETURN.
  ENDIF.

  lcl_report=>on_line_selection( ).

AT USER-COMMAND.
  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.
    WHEN OTHERS.
  ENDCASE.

" Dialog Screen modules (screen painter objects must be created separately in the system):
MODULE dialog_pbo OUTPUT.
  " PBO: populate screen fields (screen elements should be bound to these global variables)
  " fields: dialog_matnr, dialog_werks, dialog_lgnum, dialog_dst_lgtyp, dialog_dst_lgpla,
  "         dialog_src_lgtyp, dialog_src_lgpla, dialog_qty
  SET PF-STATUS 'Z9000'.
ENDMODULE.

MODULE dialog_pai INPUT.
  " PAI: validate input and submit transaction
  DATA lv_ucomm TYPE sy-ucomm.
  DATA lv_qty TYPE lqua-verme.
  lv_ucomm = ok_code.
  IF lv_ucomm IS INITIAL.
    lv_ucomm = sy-ucomm.
  ENDIF.
  CLEAR: ok_code, sy-ucomm.

  CASE lv_ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC' OR 'CANCEL' OR 'F03' OR 'F12' OR 'F15'.
      LEAVE TO SCREEN 0.
      RETURN.
    WHEN OTHERS.
      " 任何非離開類功能碼都視為建立動作，避免按鈕 function code 不一致時失效
  ENDCASE.

  IF dialog_qty IS INITIAL.
    MESSAGE '請輸入補貨數量' TYPE 'E'.
  ENDIF.

  TRY.
      lv_qty = CONV lqua-verme( dialog_qty ).
    CATCH cx_sy_conversion_error.
      MESSAGE '補貨數量格式錯誤，請輸入數字' TYPE 'E'.
  ENDTRY.

  IF lv_qty <= 0.
    MESSAGE '輸入數量需大於 0' TYPE 'E'.
  ENDIF.

  IF dialog_src_lgtyp = dialog_dst_lgtyp AND dialog_src_lgpla = dialog_dst_lgpla.
    MESSAGE '來源與目標儲位不可相同' TYPE 'E'.
  ENDIF.

  DATA(lv_src_verme) = 0.
  SELECT SINGLE verme
    FROM lqua
    WHERE matnr = @dialog_matnr
      AND werks = @dialog_werks
      AND lgnum = @dialog_lgnum
      AND lgtyp = @dialog_src_lgtyp
      AND lgpla = @dialog_src_lgpla
    INTO @lv_src_verme.

  IF lv_src_verme < lv_qty.
    MESSAGE '來源儲位庫存不足，請調整數量或選擇其他來源' TYPE 'E'.
  ENDIF.

  DATA(lv_src_frozen) = ''.
  DATA(lv_dst_frozen) = ''.
  SELECT SINGLE skzue FROM lagp
    WHERE lgnum = @dialog_lgnum
      AND lgtyp = @dialog_src_lgtyp
      AND lgpla = @dialog_src_lgpla
    INTO @lv_src_frozen.

  SELECT SINGLE skzue FROM lagp
    WHERE lgnum = @dialog_lgnum
      AND lgtyp = @dialog_dst_lgtyp
      AND lgpla = @dialog_dst_lgpla
    INTO @lv_dst_frozen.

  IF lv_src_frozen IS NOT INITIAL OR lv_dst_frozen IS NOT INITIAL.
    MESSAGE '來源或目標儲位處於凍結狀態，無法建立任務' TYPE 'E'.
  ENDIF.

  gv_new_tanum = lcl_report=>dialog_submit( ).
  IF gv_new_tanum IS INITIAL.
    MESSAGE '建立補貨任務失敗' TYPE 'E'.
  ENDIF.

  MESSAGE |已建立補貨任務 { gv_new_tanum }| TYPE 'S'.
  CALL SCREEN c_transfer_screen.
ENDMODULE.

MODULE trans_to_list OUTPUT.
  SUPPRESS DIALOG.
  LEAVE TO LIST-PROCESSING AND RETURN TO SCREEN 0.
  lcl_report=>show_transfer_log( iv_tanum = gv_new_tanum ).
ENDMODULE.