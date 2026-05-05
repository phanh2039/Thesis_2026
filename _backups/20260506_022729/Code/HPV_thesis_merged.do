* ==============================================================================
* DỰ ÁN: PHÂN TÍCH BẤT BÌNH ĐẲNG TRONG NHẬN THỨC VÀ TIÊM PHÒNG HPV
* Dữ liệu: MICS Việt Nam - Phụ nữ 15-29 tuổi
* Gộp từ: HPV_thesis_final.do + vẽ_biểu_đồ.do
*
* CẤU TRÚC FILE:
*   PHẦN 1  – Thiết lập môi trường
*   PHẦN 2  – Nạp dữ liệu & khai báo thiết kế mẫu
*   PHẦN 3  – Tạo và gán nhãn biến số
*   PHẦN 4  – Thống kê mô tả (Bảng 1)
*   PHẦN 5  – Phân tích đơn biến (Poisson + tabout)
*   PHẦN 6  – Kiểm định đa cộng tuyến (VIF)
*   PHẦN 7  – Hồi quy đa biến (aPR và aOR)
*   PHẦN 8  – Chỉ số tập trung Erreygers (conindex)
*   PHẦN 9  – Phân rã bất bình đẳng (vòng lặp thống nhất)
*   PHẦN 10 – Biểu đồ cột phân rã (bar chart)
*   PHẦN 11 – Biểu đồ Equiplot theo nhóm nhân khẩu học
*   PHẦN 12 – Đường cong tập trung (concentration curves)
* ==============================================================================


* ==============================================================================
* PHẦN 1 – THIẾT LẬP MÔI TRƯỜNG LÀM VIỆC
* ==============================================================================

clear all
set more off
set linesize 255
set type double, permanently
macro drop _all

* Thay đường dẫn cho phù hợp với máy của bạn
cd "C:\Users\phamh\HPV thesis"


* ==============================================================================
* PHẦN 2 – NẠP DỮ LIỆU VÀ KHAI BÁO THIẾT KẾ MẪU KHẢO SÁT
* ==============================================================================

use "C:\Users\phamh\HPV thesis\HPV under 30.dta"

* --- Đổi tên biến gốc sang tên ngắn gọn hơn ---
ren CCP6    ccp6    // Đã tiêm vaccine HPV? (1=Có, 2=Không)
ren CCP5    ccp5    // Đã nghe nói đến vaccine HPV? (1=Có, 2=Không)
ren wscore  ses     // Điểm SES liên tục (dùng cho conindex và glcurve)
ren windex5 ses5    // Nhóm SES phân vị 1-5 (dùng cho phân rã Erreygers)
ren HH1     ea      // Đơn vị liệt kê (enumeration area)
ren HH6     area    // Khu vực sống (1=Thành thị, 2=Nông thôn)

* --- Giữ lại mẫu phụ nữ 15-29 tuổi (WAGE = 1, 2, 3) ---
keep if inrange(WAGE, 1, 3)

* --- Loại bỏ quan sát thiếu thông tin thiết kế mẫu hoặc trọng số ---
drop if missing(wmweight) | wmweight <= 0 | missing(PSU) | missing(stratum)

* --- Khai báo thiết kế mẫu phức tạp ---
svyset, clear
svyset PSU [pweight=wmweight], strata(stratum) vce(linearized) singleunit(centered)


* ==============================================================================
* PHẦN 3 – TẠO VÀ GÁN NHÃN BIẾN SỐ
* ==============================================================================

* --- 3.1 Nhóm tuổi (WAGE) ---
label define wage_groups 1 "15-19" 2 "20-24" 3 "25-29", replace
label values WAGE wage_groups

* --- 3.2 Nhận thức vaccine HPV (ccp5_bin) ---
* 1 = Có nghe nói; 0 = Chưa nghe nói; missing nếu không trả lời
gen ccp5_bin = (ccp5 == 1) if inlist(ccp5, 1, 2)
label define yn 1 "Yes" 0 "No"
label values ccp5_bin yn

* --- 3.3 Thực hành tiêm vaccine HPV (ccp6_bin) ---
* Logic: Chưa nghe nói (ccp5=2) --> coi là chưa tiêm
gen ccp6_bin = 0
replace ccp6_bin = 1 if ccp6 == 1
replace ccp6_bin = . if missing(ccp5)
label values ccp6_bin yn

* --- 3.4 Khoảng trống nhận thức-thực hành (gap) ---
* Chỉ xác định trong nhóm đã có nhận thức (ccp5_bin == 1)
* gap=1: Biết nhưng chưa tiêm; gap=0: Biết và đã tiêm
gen gap = (ccp6_bin == 0) if ccp5_bin == 1
label define gap_lab 1 "Aware - Unvaccinated" 0 "Aware - Vaccinated"
label values gap gap_lab
label variable gap "Awareness-Vaccination Gap"

* --- 3.5 Tiếp cận truyền thông đại chúng (mme) ---
* Dựa trên 3 kênh: MT1 (Báo in), MT2 (Radio), MT3 (TV)
label define frequency_lab 0 "Not at all" 1 "<1/week" 2 ">=1/week" 3 "Everyday"
foreach v in MT1 MT2 MT3 MT4 MT5 MT12 MT10 {
    replace `v' = . if !inlist(`v', 0, 1, 2, 3)
    label values `v' frequency_lab
}
* mme=1: Tiếp cận ít nhất 1 kênh; mme=0: Không tiếp cận kênh nào
gen mme = 1
replace mme = 0 if MT1 == 0 & MT2 == 0 & MT3 == 0
replace mme = . if MT1 == .  & MT2 == .  & MT3 == .
label define mme_lbl 1 "Frequent access" 0 "Infrequent access"
label values mme mme_lbl

* --- 3.6 Thái độ bình đẳng giới (dvindex) ---
* dvindex=1: Phản đối TẤT CẢ 5 lý do bạo lực gia đình
label define dv_status 1 "Yes" 2 "No" 8 "DK"
label values DV1A DV1B DV1C DV1D DV1E dv_status
gen dvindex = (DV1A == 2 & DV1B == 2 & DV1C == 2 & DV1D == 2 & DV1E == 2)
label define dvindex_lab 1 "Rejects all wife-beating" 0 "Does not reject all"
label values dvindex dvindex_lab
label variable dvindex "Gender-equitable attitude"

* --- 3.7 Hành vi tình dục (sb1n) ---
gen sb1n = .
replace sb1n = 0 if SB1 == 0
replace sb1n = 1 if SB1 > 0 & !missing(SB1)
label define sb1_lab 0 "No" 1 "Yes"
label values sb1n sb1_lab

* --- 3.8 Tình trạng hôn nhân (MSTATUS) ---
label define mm_label 1 "Currently married/in union" ///
                      2 "Formerly married/in union"  ///
                      3 "Never married/in union"
label values MSTATUS mm_label

* --- 3.9 Khu vực sống (area) ---
label define hh6_label 1 "Urban" 2 "Rural"
label values area hh6_label

* --- 3.10 Trình độ học vấn (edu) ---
recode welevel (0 1 = 1 "Primary or less")              ///
               (2   = 2 "Lower secondary")              ///
               (3/5 = 3 "Upper secondary and tertiary") ///
               (else = .), gen(edu)

* --- 3.11 Dân tộc (ethnicity2) ---
label define eth_lab 1 "Kinh/Hoa" 2 "Ethnic minority"
label values ethnicity2 eth_lab

* --- 3.12 Danh sách biến độc lập chuẩn (dùng chung cho mọi mô hình) ---
* Lưu ý: ses5 được đưa vào để phân tích theo nhóm giàu nghèo (Q1-Q5)
*         sb1n đã bị loại sau kiểm định VIF (xem Phần 6)
global X_full "i.area i.WAGE i.MSTATUS i.edu i.insurance i.ethnicity2 i.mme i.dvindex i.ses5"


* ==============================================================================
* PHẦN 4 – THỐNG KÊ MÔ TẢ (BẢNG 1)
* ==============================================================================

* Xuất bảng mô tả đặc điểm đối tượng nghiên cứu ra file Word
asdoc tab WAGE [aw=wmweight], percent replace dec(1) ///
    title(Bang 1: Dac diem doi tuong nghien cuu) save(Table1_Mota.doc)

foreach x in area ethnicity2 insurance MSTATUS edu ses5 ccp5_bin ccp6_bin mme dvindex sb1n {
    asdoc tab `x' [aw=wmweight], percent append dec(1) save(Table1_Mota.doc)
}


* ==============================================================================
* PHẦN 5 – PHÂN TÍCH ĐƠN BIẾN (POISSON + TABOUT)
* ==============================================================================

* --- 5.1 Bảng tỷ lệ hàng và kiểm định chi-squared có trọng số khảo sát ---
tabout WAGE area ethnicity2 insurance MSTATUS edu ses5 dvindex mme sb1n ccp5_bin ///
    using "CCP5_moi_lien_quan.xls", ///
    svy c(row ci) f(3 3) stats(chi2) h1("Moi lien quan voi nhan thuc vaccine HPV") replace

tabout WAGE area ethnicity2 insurance MSTATUS edu ses5 dvindex mme sb1n ccp6_bin ///
    using "CCP6_moi_lien_quan.xls", ///
    svy c(row ci) f(3 3) stats(chi2) h1("Moi lien quan voi tiem phong vaccine HPV") replace

* --- 5.2 Hồi quy Poisson đơn biến – ccp5_bin (Nhận thức) ---
asdoc, text(DON BIEN: ccp5_bin - Nhan thuc vaccine HPV) replace save(DonBien_Results.doc)
foreach x in i.area i.WAGE i.MSTATUS i.edu i.insurance i.ethnicity2 ///
             i.ses5 i.mme i.dvindex i.sb1n {
    capture drop __*
    asdoc svy: poisson ccp5_bin `x', irr append save(DonBien_Results.doc) title(PR for Awareness)
}

* --- 5.3 Hồi quy Poisson đơn biến – ccp6_bin (Tiêm chủng) ---
asdoc, text(DON BIEN: ccp6_bin - Tiem phong vaccine HPV) append save(DonBien_Results.doc)
foreach x in i.area i.WAGE i.MSTATUS i.edu i.insurance i.ethnicity2 ///
             i.ses5 i.mme i.dvindex i.sb1n {
    capture drop __*
    asdoc svy: poisson ccp6_bin `x', irr append save(DonBien_Results.doc) title(PR for Vaccination)
}


* ==============================================================================
* PHẦN 6 – KIỂM ĐỊNH ĐA CỘNG TUYẾN (VIF)
* ==============================================================================

* Dùng OLS (regress) để tính VIF; VIF > 10 --> cân nhắc loại biến
quietly regress ccp5_bin $X_full
vif
* Ghi chú: Nếu sb1n có VIF cao, đã loại khỏi global X_full ở Phần 3

quietly regress ccp6_bin $X_full
vif


* ==============================================================================
* PHẦN 7 – HỒI QUY ĐA BIẾN (aPR VÀ aOR)
* ==============================================================================

* --- 7.1 Poisson đa biến cho Nhận thức (aPR = Adjusted Prevalence Ratio) ---
asdoc svy: poisson ccp5_bin $X_full, irr replace dec(3) ///
    save(DaBien_Results.doc) title(Bang aPR: Nhan thuc vaccine HPV)

* --- 7.2 Logistic đa biến cho Tiêm chủng (aOR = Adjusted Odds Ratio) ---
asdoc svy: logistic ccp6_bin $X_full, append dec(3) ///
    save(DaBien_Results.doc) title(Bang aOR: Tiem phong vaccine HPV)

display "DA XONG! Mo file DaBien_Results.doc de lay aPR va aOR."


* ==============================================================================
* PHẦN 8 – CHỈ SỐ TẬP TRUNG ERREYGERS (CONINDEX)
* ==============================================================================

* bounded limits(0 1): biến kết cục bị chặn trong [0,1]
* erreygers: dùng chỉ số E của Erreygers, phù hợp hơn với biến bị chặn
* rank(ses5): xếp hạng theo phân vị kinh tế-xã hội

conindex ccp5_bin, rank(ses5) bounded limits(0 1) erreygers svy
conindex ccp6_bin, rank(ses5) bounded limits(0 1) erreygers svy
conindex gap,      rank(ses5) bounded limits(0 1) erreygers svy

* Xuất bảng chỉ số tập trung ra file Word
asdoc conindex ccp5_bin, rank(ses5) bounded limits(0 1) erreygers svy ///
    replace title(Chi so tap trung Erreygers) save(Conindex_Tables.doc) dec(3)
asdoc conindex ccp6_bin, rank(ses5) bounded limits(0 1) erreygers svy ///
    append save(Conindex_Tables.doc) dec(3)
asdoc conindex gap,      rank(ses5) bounded limits(0 1) erreygers svy ///
    append save(Conindex_Tables.doc) dec(3)


* ==============================================================================
* PHẦN 9 – PHÂN RÃ BẤT BÌNH ĐẲNG ERREYGERS (VÒNG LẶP THỐNG NHẤT)
*
* Chạy 1 vòng lặp cho 3 biến kết cục: ccp5_bin, ccp6_bin, gap
* Công thức Erreygers: Contribution_k = 4 × (dy/dx_k) × mean_k × CI_k
*
* Đầu ra: Bao_Cao_Phan_Ra_HPV.xlsx (3 sheet: CCP5_BIN, CCP6_BIN, GAP)
* ==============================================================================

foreach outcome in ccp5_bin ccp6_bin gap {

    local sheetname = upper("`outcome'")

    * --- Khởi tạo file tạm lưu kết quả (5 cột) ---
    tempname memhold
    postfile `memhold' str60 variable double dydx double CI_x ///
        double contrib double percentage using "Temp_`outcome'.dta", replace

    * --- Tính Concentration Index (CI) tổng thể ---
    qui conindex `outcome', rank(ses5) bounded limits(0 1) erreygers svy
    scalar CI_total    = r(CI)
    scalar sum_contrib = 0      // Dùng để tính Residual sau vòng lặp

    * --- Hồi quy GLM Probit + Marginal Effects (dy/dx) ---
    qui svy: glm `outcome' $X_full, family(binomial) link(probit)
    qui margins, dydx(*) post
    estimates store m_`outcome'

    * --- Vòng lặp tính đóng góp từng hệ số ---
    local regs : colnames e(b)
    foreach bn in `regs' {
        if "`bn'" == "_cons" continue      // Bỏ qua hằng số

        qui estimates restore m_`outcome'
        _ms_parse_parts `bn'
        scalar b_val = _b[`bn']            // Marginal Effect (dy/dx)

        qui {
            tempvar temp_v
            gen byte `temp_v' = (`bn')
            capture conindex `temp_v', rank(ses5) bounded limits(0 1) erreygers svy

            if _rc == 0 {
                scalar CI_x_val = r(CI)         // CI của biến độc lập X_k
                qui sum `temp_v' [aw=wmweight]
                scalar m_x = r(mean)            // Trung bình của X_k

                * Công thức Erreygers: 4 × ME × mean × CI_x
                scalar contrib_val = 4 * b_val * m_x * CI_x_val
                scalar pct_val     = (contrib_val / CI_total) * 100
                scalar sum_contrib = sum_contrib + contrib_val

                post `memhold' ("`bn'") (b_val) (CI_x_val) (contrib_val) (pct_val)
            }
            drop `temp_v'
        }
    }

    * --- Tính Phần dư: Residual = CI_tổng - Tổng đóng góp ---
    scalar res_val = CI_total - sum_contrib
    scalar res_pct = (res_val / CI_total) * 100
    post `memhold' ("Residual") (.) (.) (res_val) (res_pct)
    postclose `memhold'

    * --- Định dạng, gán nhãn và xuất kết quả ra Excel ---
    preserve
        use "Temp_`outcome'.dta", clear

        * Nhãn tiếng Anh cho từng dòng biến
        replace variable = "Urban area (Ref: Rural)"    if variable == "1.area"
        replace variable = "Rural area"                 if variable == "2.area"
        replace variable = "Age 20-24 (Ref: 15-19)"    if variable == "2.WAGE"
        replace variable = "Age 25-29 (Ref: 15-19)"    if variable == "3.WAGE"
        replace variable = "Formerly married"           if variable == "2.MSTATUS"
        replace variable = "Never married"              if variable == "3.MSTATUS"
        replace variable = "Lower secondary edu."       if variable == "2.edu"
        replace variable = "Upper secondary & Tertiary" if variable == "3.edu"
        replace variable = "Uninsured"                  if variable == "2.insurance"
        replace variable = "Ethnic minority"            if variable == "2.ethnicity2"
        replace variable = "Mass media exposure"        if variable == "1.mme"
        replace variable = "Rejects wife-beating"       if variable == "1.dvindex"
        replace variable = "Q2 (Poorer)"                if variable == "2.ses5"
        replace variable = "Q3 (Middle)"                if variable == "3.ses5"
        replace variable = "Q4 (Richer)"                if variable == "4.ses5"
        replace variable = "Q5 (Richest)"               if variable == "5.ses5"

        * Định dạng số thập phân
        format dydx CI_x contrib %9.4f
        format percentage %9.1f

        * Sắp xếp: đóng góp tuyệt đối lớn nhất lên đầu; Residual xuống cuối
        gen sort_order = abs(contrib)
        replace sort_order = -1 if variable == "Residual"
        gsort -sort_order
        drop sort_order

        * Gán nhãn cột cho Excel
        label var variable   "Variable"
        label var dydx       "dy/dx"
        label var CI_x       "CIx"
        label var contrib    "Contribution"
        label var percentage "% of total"

        export excel using "Bao_Cao_Phan_Ra_HPV.xlsx", ///
            sheet("`sheetname'") firstrow(varlabels) sheetreplace
    restore
}

display _n "--- PHAN RA HOAN TAT! File 'Bao_Cao_Phan_Ra_HPV.xlsx' co 3 sheet ---"


* ==============================================================================
* PHẦN 10 – BIỂU ĐỒ CỘT PHÂN RÃ BẤT BÌNH ĐẲNG (BAR CHART)
* Màu sắc: cam (Awareness), xanh lá (Vaccination), xanh dương (Gap)
* ==============================================================================

foreach outcome in ccp5_bin ccp6_bin gap {

    if "`outcome'" == "ccp5_bin" {
        local bar_color "orange"
        local bar_title "Decomposition of Inequality in HPV Awareness"
    }
    else if "`outcome'" == "ccp6_bin" {
        local bar_color "green"
        local bar_title "Decomposition of Inequality in HPV Vaccination"
    }
    else {
        local bar_color "blue"
        local bar_title "Decomposition of Inequality in Awareness-Vaccination Gap"
    }

    preserve
        use "Temp_`outcome'.dta", clear

        * Áp lại nhãn tiếng Anh (file tạm chưa được đổi nhãn ở lần đọc này)
        replace variable = "Urban area (Ref: Rural)"    if variable == "1.area"
        replace variable = "Rural area"                 if variable == "2.area"
        replace variable = "Age 20-24"                  if variable == "2.WAGE"
        replace variable = "Age 25-29"                  if variable == "3.WAGE"
        replace variable = "Formerly married"           if variable == "2.MSTATUS"
        replace variable = "Never married"              if variable == "3.MSTATUS"
        replace variable = "Lower secondary edu."       if variable == "2.edu"
        replace variable = "Upper secondary & Tertiary" if variable == "3.edu"
        replace variable = "Uninsured"                  if variable == "2.insurance"
        replace variable = "Ethnic minority"            if variable == "2.ethnicity2"
        replace variable = "Mass media exposure"        if variable == "1.mme"
        replace variable = "Rejects wife-beating"       if variable == "1.dvindex"
        replace variable = "Q2 (Poorer)"                if variable == "2.ses5"
        replace variable = "Q3 (Middle)"                if variable == "3.ses5"
        replace variable = "Q4 (Richer)"                if variable == "4.ses5"
        replace variable = "Q5 (Richest)"               if variable == "5.ses5"

        drop if variable == "Residual"
        gen abs_contrib = abs(contrib)

        graph hbar (asis) contrib, ///
            over(variable, sort(abs_contrib) descending ///
                label(labsize(vsmall) labcolor(black))) ///
            bar(1, fcolor(`bar_color') lcolor(black) lwidth(vthin)) ///
            yline(0, lcolor(gs8) lpattern(dash)) ///
            ytitle("Contribution to Erreygers CI", size(small)) ///
            title("`bar_title'", size(medium) color(black)) ///
            graphregion(color(white)) bgcolor(white) ///
            name(gr_`outcome', replace)

        graph export "Decomp_`outcome'.png", replace
    restore
}

display _n "--- DA VE XONG 3 BIEU DO COT PHAN RA ---"


* ==============================================================================
* PHẦN 11 – BIỂU ĐỒ EQUIPLOT THEO NHÓM NHÂN KHẨU HỌC
* rcap = khoảng tin cậy 95%; scatter = điểm ước tính tỷ lệ %
* ==============================================================================

* -----------------------------------------------------------------------
* 11.1 Equiplot: theo nhóm giàu nghèo (ses5 – 5 nhóm)
* -----------------------------------------------------------------------

* (a) Gap theo giàu nghèo
qui svy: mean gap, over(ses5)
matrix r_gap = r(table)

preserve
    clear
    set obs 5
    gen q  = _n
    gen m  = .
    gen lb = .
    gen ub = .
    forvalues i = 1/5 {
        replace m  = r_gap[1,`i']*100 in `i'
        replace lb = r_gap[5,`i']*100 in `i'
        replace ub = r_gap[6,`i']*100 in `i'
    }
    gen y_pos = 1
    twoway ///
        (rcap lb ub y_pos, horizontal lcolor(gs12)) ///
        (scatter y_pos m if q==1, mcolor(ltblue)     msize(large)) ///
        (scatter y_pos m if q==2, mcolor(cyan)       msize(large)) ///
        (scatter y_pos m if q==3, mcolor(teal)       msize(large)) ///
        (scatter y_pos m if q==4, mcolor(blue)       msize(large)) ///
        (scatter y_pos m if q==5, mcolor(navy)       msize(large)), ///
        title("Awareness-Vaccination Gap by Wealth Quintile", size(medium) color(black)) ///
        xtitle("Weighted prevalence (%)") xlabel(0(20)100) ///
        ylabel(1 "Gap among aware women", angle(0) noticks) ytitle("") ///
        yscale(range(0.5 1.5)) ///
        legend(order(2 "Q1 poorest" 3 "Q2" 4 "Q3" 5 "Q4" 6 "Q5 richest") ///
               rows(1) pos(6) size(vsmall) region(lcolor(white))) ///
        graphregion(color(white)) bgcolor(white) name(equiplot_gap, replace)
    graph export "Equiplot_Gap_SES.png", replace
restore

* (b) Tiêm chủng theo giàu nghèo
qui svy: mean ccp6_bin, over(ses5)
matrix r_ccp6 = r(table)

preserve
    clear
    set obs 5
    gen q  = _n
    gen m  = .
    gen lb = .
    gen ub = .
    forvalues i = 1/5 {
        replace m  = r_ccp6[1,`i']*100 in `i'
        replace lb = r_ccp6[5,`i']*100 in `i'
        replace ub = r_ccp6[6,`i']*100 in `i'
    }
    gen y_pos = 1
    twoway ///
        (rcap lb ub y_pos, horizontal lcolor(gs12)) ///
        (scatter y_pos m if q==1, mcolor(ltgreen)      msize(large)) ///
        (scatter y_pos m if q==2, mcolor(lime)         msize(large)) ///
        (scatter y_pos m if q==3, mcolor(green)        msize(large)) ///
        (scatter y_pos m if q==4, mcolor(forest_green) msize(large)) ///
        (scatter y_pos m if q==5, mcolor(dkgreen)      msize(large)), ///
        title("HPV Vaccination Status by Wealth Quintile", size(medium) color(black)) ///
        xtitle("Weighted prevalence (%)") xlabel(0(20)100) ///
        ylabel(1 "Vaccination practice", angle(0) noticks) ytitle("") ///
        yscale(range(0.5 1.5)) ///
        legend(order(2 "Q1 poorest" 3 "Q2" 4 "Q3" 5 "Q4" 6 "Q5 richest") ///
               rows(1) pos(6) size(vsmall) region(lcolor(white))) ///
        graphregion(color(white)) bgcolor(white) name(equiplot_vac, replace)
    graph export "Equiplot_Vaccination_SES.png", replace
restore

* (c) Nhận thức theo giàu nghèo
qui svy: mean ccp5_bin, over(ses5)
matrix r_ccp5 = r(table)

preserve
    clear
    set obs 5
    gen q  = _n
    gen m  = .
    gen lb = .
    gen ub = .
    forvalues i = 1/5 {
        replace m  = r_ccp5[1,`i']*100 in `i'
        replace lb = r_ccp5[5,`i']*100 in `i'
        replace ub = r_ccp5[6,`i']*100 in `i'
    }
    gen y_pos = 1
    twoway ///
        (rcap lb ub y_pos, horizontal lcolor(gs12)) ///
        (scatter y_pos m if q==1, mcolor(sand)       msize(large)) ///
        (scatter y_pos m if q==2, mcolor(ltkhaki)    msize(large)) ///
        (scatter y_pos m if q==3, mcolor(orange)     msize(large)) ///
        (scatter y_pos m if q==4, mcolor(orange_red) msize(large)) ///
        (scatter y_pos m if q==5, mcolor(sienna)     msize(large)), ///
        title("HPV Awareness by Wealth Quintile", size(medium) color(black)) ///
        xtitle("Weighted prevalence (%)") xlabel(0(20)100) ///
        ylabel(1 "Awareness", angle(0) noticks) ytitle("") ///
        yscale(range(0.5 1.5)) ///
        legend(order(2 "Q1 poorest" 3 "Q2" 4 "Q3" 5 "Q4" 6 "Q5 richest") ///
               rows(1) pos(6) size(vsmall) region(lcolor(white))) ///
        graphregion(color(white)) bgcolor(white) name(equiplot_awa, replace)
    graph export "Equiplot_Awareness_SES.png", replace
restore

* -----------------------------------------------------------------------
* 11.2 Equiplot: Nhận thức vs Tiêm chủng theo biến nhân khẩu học
* -----------------------------------------------------------------------

* (a) Dân tộc (2 nhóm)
qui svy: mean ccp5_bin, over(ethnicity2)
matrix r_awa = r(table)
qui svy: mean ccp6_bin, over(ethnicity2)
matrix r_vac = r(table)

preserve
    clear
    local n_cats = 2
    set obs `= `n_cats' * 2'
    gen y_pos = cond(_n <= `n_cats', 2, 1)
    gen group = mod(_n-1, `n_cats') + 1
    gen m  = .
    gen lb = .
    gen ub = .
    forvalues i = 1/`n_cats' {
        replace m  = r_awa[1,`i']*100 if y_pos==2 & group==`i'
        replace lb = r_awa[5,`i']*100 if y_pos==2 & group==`i'
        replace ub = r_awa[6,`i']*100 if y_pos==2 & group==`i'
        replace m  = r_vac[1,`i']*100 if y_pos==1 & group==`i'
        replace lb = r_vac[5,`i']*100 if y_pos==1 & group==`i'
        replace ub = r_vac[6,`i']*100 if y_pos==1 & group==`i'
    }
    twoway ///
        (rcap lb ub y_pos if group==1, horizontal lcolor(lime)) ///
        (rcap lb ub y_pos if group==2, horizontal lcolor(magenta)) ///
        (scatter y_pos m if group==1, mcolor(lime)    msize(large)) ///
        (scatter y_pos m if group==2, mcolor(magenta) msize(large)), ///
        title("HPV Awareness and Vaccination by Ethnicity", size(medium) color(black)) ///
        xtitle("Weighted prevalence (%)") xlabel(0(10)100) ///
        ylabel(1 "HPV vaccination" 2 "HPV awareness", angle(0) noticks) ytitle("") ///
        yscale(range(0.5 2.5)) ///
        legend(order(3 "Kinh/Hoa" 4 "Ethnic minority") ///
               rows(1) pos(6) size(vsmall) region(lcolor(white))) ///
        graphregion(color(white)) bgcolor(white) name(eq_eth, replace)
    graph export "Equiplot_Ethnicity.png", replace
restore

* (b) Khu vực sống (2 nhóm)
qui svy: mean ccp5_bin, over(area)
matrix r_awa = r(table)
qui svy: mean ccp6_bin, over(area)
matrix r_vac = r(table)

preserve
    clear
    local n_cats = 2
    set obs `= `n_cats' * 2'
    gen y_pos = cond(_n <= `n_cats', 2, 1)
    gen group = mod(_n-1, `n_cats') + 1
    gen m  = .
    gen lb = .
    gen ub = .
    forvalues i = 1/`n_cats' {
        replace m  = r_awa[1,`i']*100 if y_pos==2 & group==`i'
        replace lb = r_awa[5,`i']*100 if y_pos==2 & group==`i'
        replace ub = r_awa[6,`i']*100 if y_pos==2 & group==`i'
        replace m  = r_vac[1,`i']*100 if y_pos==1 & group==`i'
        replace lb = r_vac[5,`i']*100 if y_pos==1 & group==`i'
        replace ub = r_vac[6,`i']*100 if y_pos==1 & group==`i'
    }
    twoway ///
        (rcap lb ub y_pos if group==1, horizontal lcolor(purple)) ///
        (rcap lb ub y_pos if group==2, horizontal lcolor(pink)) ///
        (scatter y_pos m if group==1, mcolor(purple) msize(large)) ///
        (scatter y_pos m if group==2, mcolor(pink)   msize(large)), ///
        title("HPV Awareness and Vaccination by Residential Area", size(medium) color(black)) ///
        xtitle("Weighted prevalence (%)") xlabel(0(10)100) ///
        ylabel(1 "HPV vaccination" 2 "HPV awareness", angle(0) noticks) ytitle("") ///
        yscale(range(0.5 2.5)) ///
        legend(order(3 "Urban" 4 "Rural") ///
               rows(1) pos(6) size(vsmall) region(lcolor(white))) ///
        graphregion(color(white)) bgcolor(white) name(eq_area, replace)
    graph export "Equiplot_Area.png", replace
restore

* (c) Trình độ học vấn (3 nhóm)
qui svy: mean ccp5_bin, over(edu)
matrix r_awa = r(table)
qui svy: mean ccp6_bin, over(edu)
matrix r_vac = r(table)

preserve
    clear
    local n_cats = 3
    set obs `= `n_cats' * 2'
    gen y_pos = cond(_n <= `n_cats', 2, 1)
    gen group = mod(_n-1, `n_cats') + 1
    gen m  = .
    gen lb = .
    gen ub = .
    forvalues i = 1/`n_cats' {
        replace m  = r_awa[1,`i']*100 if y_pos==2 & group==`i'
        replace lb = r_awa[5,`i']*100 if y_pos==2 & group==`i'
        replace ub = r_awa[6,`i']*100 if y_pos==2 & group==`i'
        replace m  = r_vac[1,`i']*100 if y_pos==1 & group==`i'
        replace lb = r_vac[5,`i']*100 if y_pos==1 & group==`i'
        replace ub = r_vac[6,`i']*100 if y_pos==1 & group==`i'
    }
    twoway ///
        (rcap lb ub y_pos if group==1, horizontal lcolor(gs12)) ///
        (rcap lb ub y_pos if group==2, horizontal lcolor(gs12)) ///
        (rcap lb ub y_pos if group==3, horizontal lcolor(gs12)) ///
        (scatter y_pos m if group==1, mcolor(red)    msize(large)) ///
        (scatter y_pos m if group==2, mcolor(blue)   msize(large)) ///
        (scatter y_pos m if group==3, mcolor(yellow) msize(large)), ///
        title("HPV Awareness and Vaccination by Education", size(medium) color(black)) ///
        xtitle("Weighted prevalence (%)") xlabel(0(10)100) ///
        ylabel(1 "HPV vaccination" 2 "HPV awareness", angle(0) noticks) ytitle("") ///
        yscale(range(0.5 2.5)) ///
        legend(order(4 "Primary or less" 5 "Lower secondary" 6 "Upper secondary+") ///
               rows(1) pos(6) size(vsmall) region(lcolor(white))) ///
        graphregion(color(white)) bgcolor(white) name(eq_edu, replace)
    graph export "Equiplot_Education.png", replace
restore

* (d) Nhóm tuổi (3 nhóm)
qui svy: mean ccp5_bin, over(WAGE)
matrix r_awa = r(table)
qui svy: mean ccp6_bin, over(WAGE)
matrix r_vac = r(table)

preserve
    clear
    local n_cats = 3
    set obs `= `n_cats' * 2'
    gen y_pos = cond(_n <= `n_cats', 2, 1)
    gen group = mod(_n-1, `n_cats') + 1
    gen m  = .
    gen lb = .
    gen ub = .
    forvalues i = 1/`n_cats' {
        replace m  = r_awa[1,`i']*100 if y_pos==2 & group==`i'
        replace lb = r_awa[5,`i']*100 if y_pos==2 & group==`i'
        replace ub = r_awa[6,`i']*100 if y_pos==2 & group==`i'
        replace m  = r_vac[1,`i']*100 if y_pos==1 & group==`i'
        replace lb = r_vac[5,`i']*100 if y_pos==1 & group==`i'
        replace ub = r_vac[6,`i']*100 if y_pos==1 & group==`i'
    }
    twoway ///
        (rcap lb ub y_pos if group==1, horizontal lcolor(gs12)) ///
        (rcap lb ub y_pos if group==2, horizontal lcolor(gs12)) ///
        (rcap lb ub y_pos if group==3, horizontal lcolor(gs12)) ///
        (scatter y_pos m if group==1, mcolor(green)  msize(large)) ///
        (scatter y_pos m if group==2, mcolor(orange) msize(large)) ///
        (scatter y_pos m if group==3, mcolor(pink)   msize(large)), ///
        title("HPV Awareness and Vaccination by Age Group", size(medium) color(black)) ///
        xtitle("Weighted prevalence (%)") xlabel(0(10)100) ///
        ylabel(1 "HPV vaccination" 2 "HPV awareness", angle(0) noticks) ytitle("") ///
        yscale(range(0.5 2.5)) ///
        legend(order(4 "15-19" 5 "20-24" 6 "25-29") ///
               rows(1) pos(6) size(vsmall) region(lcolor(white))) ///
        graphregion(color(white)) bgcolor(white) name(eq_age, replace)
    graph export "Equiplot_Age.png", replace
restore

* (e) Tình trạng hôn nhân (3 nhóm)
qui svy: mean ccp5_bin, over(MSTATUS)
matrix r_awa = r(table)
qui svy: mean ccp6_bin, over(MSTATUS)
matrix r_vac = r(table)

preserve
    clear
    local n_cats = 3
    set obs `= `n_cats' * 2'
    gen y_pos = cond(_n <= `n_cats', 2, 1)
    gen group = mod(_n-1, `n_cats') + 1
    gen m  = .
    gen lb = .
    gen ub = .
    forvalues i = 1/`n_cats' {
        replace m  = r_awa[1,`i']*100 if y_pos==2 & group==`i'
        replace lb = r_awa[5,`i']*100 if y_pos==2 & group==`i'
        replace ub = r_awa[6,`i']*100 if y_pos==2 & group==`i'
        replace m  = r_vac[1,`i']*100 if y_pos==1 & group==`i'
        replace lb = r_vac[5,`i']*100 if y_pos==1 & group==`i'
        replace ub = r_vac[6,`i']*100 if y_pos==1 & group==`i'
    }
    twoway ///
        (rcap lb ub y_pos if group==1, horizontal lcolor(gs12)) ///
        (rcap lb ub y_pos if group==2, horizontal lcolor(gs12)) ///
        (rcap lb ub y_pos if group==3, horizontal lcolor(gs12)) ///
        (scatter y_pos m if group==1, mcolor(purple) msize(large)) ///
        (scatter y_pos m if group==2, mcolor(cyan)   msize(large)) ///
        (scatter y_pos m if group==3, mcolor(brown)  msize(large)), ///
        title("HPV Awareness and Vaccination by Marital Status", size(medium) color(black)) ///
        xtitle("Weighted prevalence (%)") xlabel(0(10)100) ///
        ylabel(1 "HPV vaccination" 2 "HPV awareness", angle(0) noticks) ytitle("") ///
        yscale(range(0.5 2.5)) ///
        legend(order(4 "Currently married/union" 5 "Formerly married/union" ///
                     6 "Never married/union") ///
               rows(1) pos(6) size(vsmall) region(lcolor(white))) ///
        graphregion(color(white)) bgcolor(white) name(eq_status, replace)
    graph export "Equiplot_MaritalStatus.png", replace
restore

display _n "--- DA VE XONG TAT CA BIEU DO EQUIPLOT ---"


* ==============================================================================
* PHẦN 12 – ĐƯỜNG CONG TẬP TRUNG (CONCENTRATION CURVES)
* glcurve tạo tọa độ; vẽ gộp 3 đường + đường bình đẳng (y=x)
* ==============================================================================

* Tạo tọa độ đường cong cho 3 biến kết cục (xếp hạng theo ses liên tục)
glcurve ccp5_bin [aw=wmweight], glvar(y_ccp5) pvar(x_rank) sortvar(ses) lorenz replace
glcurve ccp6_bin [aw=wmweight], glvar(y_ccp6)               sortvar(ses) lorenz replace
glcurve gap      [aw=wmweight], glvar(y_gap)                 sortvar(ses) lorenz replace

* Vẽ biểu đồ gộp
twoway ///
    (line y_ccp5 x_rank, sort lcolor(orange)       lpattern(solid)     lwidth(medthick)) ///
    (line y_ccp6 x_rank, sort lcolor(forest_green) lpattern(longdash)  lwidth(medthick)) ///
    (line y_gap  x_rank, sort lcolor(blue)         lpattern(shortdash) lwidth(medthick)) ///
    (function y=x, range(0 1) lcolor(maroon) lpattern(dot) lwidth(medthick)), ///
    title("Concentration Curves: HPV Awareness, Vaccination and Gap", ///
          size(medium) color(black)) ///
    ytitle("Cumulative share of outcome") ///
    xtitle("Cumulative share of population (ranked by SES)") ///
    legend(order(1 "HPV Awareness" 2 "HPV Vaccination" ///
                 3 "Gap" 4 "Line of Equality") ///
           position(6) cols(2) region(lcolor(white))) ///
    graphregion(color(white)) name(combined_curves, replace)

graph export "Concentration_Curves_HPV.png", replace


* ==============================================================================
* HOÀN TẤT – TÓM TẮT CÁC FILE ĐẦU RA
* ==============================================================================

display _n "========================================================"
display    " HOAN TAT TOAN BO PHAN TICH - HPV THESIS"
display    "========================================================"
display    " FILE WORD  : Table1_Mota.doc"
display    "              DonBien_Results.doc"
display    "              DaBien_Results.doc"
display    "              Conindex_Tables.doc"
display    " FILE EXCEL : CCP5_moi_lien_quan.xls"
display    "              CCP6_moi_lien_quan.xls"
display    "              Bao_Cao_Phan_Ra_HPV.xlsx (3 sheets)"
display    " BIEU DO PNG: Decomp_ccp5_bin.png"
display    "              Decomp_ccp6_bin.png"
display    "              Decomp_gap.png"
display    "              Equiplot_Gap_SES.png"
display    "              Equiplot_Vaccination_SES.png"
display    "              Equiplot_Awareness_SES.png"
display    "              Equiplot_Ethnicity.png"
display    "              Equiplot_Area.png"
display    "              Equiplot_Education.png"
display    "              Equiplot_Age.png"
display    "              Equiplot_MaritalStatus.png"
display    "              Concentration_Curves_HPV.png"
display    "========================================================"
