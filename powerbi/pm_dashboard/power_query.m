// PM Dashboard: Power Query 주요 단계 (익명화, 원천 경로는 placeholder, 일부 단계는 동일 로직으로 축약)

// ===== Milestones: 프로젝트 마일스톤 =====
let
    Source = Excel.Workbook(Web.Contents("<SharePoint>/PM Task Alignment.xlsm"), null, true),
    Milestones_Sheet = Source{[Item="Milestones",Kind="Sheet"]}[Data],
    #"Removed Blank Rows" = Table.SelectRows(Milestones_Sheet, each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
    #"Removed Top Rows" = Table.Skip(#"Removed Blank Rows", 4),
    #"Promoted Headers" = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),
    #"Replaced Null" = Table.ReplaceValue(#"Promoted Headers", null, "N/A", Replacer.ReplaceValue, {"PO","Order","Done","Invoiced","Shipped"}),
    // 단계별 표시(● 완료, O 진행 중)를 읽어 현재 마일스톤 결정
    #"Added Milestone" = Table.AddColumn(#"Replaced Null", "Milestone", each
        if Text.Contains([Shipped], "●") then "Project Ended"
        else if Text.Contains([Shipped], "O") then "On Shipping"
        else if Text.Contains([Invoiced], "●") then "Invoiced"
        else if Text.Contains([Done], "●") then "Production Ended"
        else if Text.Contains([Done], "O") then "On Production"
        else if Text.Contains([Order], "●") then "Material Ordered"
        else if Text.Contains([PO], "●") then "Project Received"
        else "Project Pending"),
    #"Added MilestoneIndex" = Table.AddColumn(#"Added Milestone", "MilestoneIndex", each
        List.PositionOf({"Project Ended","On Shipping","Invoiced","Production Ended","On Production","Material Ordered","Project Received","Project Pending"}, [Milestone]) + 1),
        // 원본은 중첩 if
    // 영업 프로젝트 목록 병합 → 유닛 수량, 유닛당 단가
    #"Merged Sales" = Table.NestedJoin(#"Added MilestoneIndex", {"Project ID"}, __SalesProject, {"Project ID"}, "__SalesProject", JoinKind.LeftOuter),
    #"Expanded Sales" = Table.ExpandTableColumn(#"Merged Sales", "__SalesProject", {"Product Qty", "Unit Per Product", "Revenue Total($k)"}),
    #"Added Unit Qty" = Table.AddColumn(#"Expanded Sales", "Unit Qty", each [Product Qty] * [Unit Per Product], Int64.Type),
    #"Added Price" = Table.AddColumn(#"Added Unit Qty", "Price/Unit", each [#"Revenue Total($k)"] / [Unit Qty], Currency.Type),
    // 공개본: 고객사명 치환
    #"Replaced Customer" = List.Accumulate({{"<A>","Customer1"},{"<B>","Customer2"},{"<C>","Customer3"},{"<D>","Customer4"}}, #"Added Price",
        (t, r) => Table.ReplaceValue(t, r{0}, r{1}, Replacer.ReplaceText, {"Customer"}))
in
    #"Replaced Customer"

// ===== _<Category>: 카테고리별 이슈 시트 (8개 동일 구조) =====
let
    Source = Excel.Workbook(Web.Contents("<SharePoint>/PM Task Alignment.xlsm"), null, true),
    Sheet = Source{[Item="<Category>",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Sheet, [PromoteAllScalars=true]),
    #"Removed Blank Rows" = Table.SelectRows(#"Promoted Headers", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
    #"Removed Top Rows" = Table.Skip(#"Removed Blank Rows", 1),
    #"Promoted Headers1" = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),
    #"Merged Milestones" = Table.NestedJoin(#"Promoted Headers1", {"Project"}, Milestones, {"Project"}, "Milestones", JoinKind.LeftOuter),
    #"Expanded Milestones" = Table.ExpandTableColumn(#"Merged Milestones", "Milestones", {"ProjectName"}, {"Milestones.ProjectName"})
in
    #"Expanded Milestones"

// ===== __UnitRelease: 유닛별 공정 완료 일자 =====
let
    Source = Excel.Workbook(Web.Contents("<SharePoint>/Unit Release.xlsx"), null, true),
    Sheet0 = Source{[Item="Sheet0",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Sheet0, [PromoteAllScalars=true]),
    #"Merged Milestones" = Table.NestedJoin(#"Promoted Headers", {"Project ID"}, Milestones, {"Project ID"}, "Milestones", JoinKind.LeftOuter),
    #"Expanded Milestones" = Table.ExpandTableColumn(#"Merged Milestones", "Milestones", {"ProjectName", "MilestoneIndex"}, {"Milestones.ProjectName", "Milestones.MilestoneIndex"}),
    #"Added Unit Type" = Table.AddColumn(#"Expanded Milestones", "Unit Type", each Text.End([Unit ID], 1), type text),
    // 전년도 완료분을 당해 연도 1월 1일로 보정 (대상 프로젝트 한정)
    #"Added S3 Done Adjusted" = Table.AddColumn(#"Added Unit Type", "S3 Done Adjusted", each
        if List.Contains({"Project A", "Project B"}, [Project Desc]) and [S3 Done] < #date(2025,1,1) then #date(2025,1,1) else [S3 Done]),
    #"Added Key" = Table.AddColumn(#"Added S3 Done Adjusted", "ID", each Text.Combine({Text.From([Project ID], "en-US"), "-", [Unit ID]}), type text)
in
    #"Added Key"

// ===== __UnitStatus: 유닛 현재 공정 상태 =====
let
    Source = Excel.Workbook(Web.Contents("<SharePoint>/Unit Status.xlsx"), null, true),
    Sheet1 = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Table.PromoteHeaders(Sheet1, [PromoteAllScalars=true]), [PromoteAllScalars=true]),   // 2단 헤더
    // (불필요 컬럼 제거·이름 변경 단계 생략)
    #"Added S3Start" = Table.AddColumn(#"Promoted Headers", "S3Start", each
        if [S3AStart] = null and [S3BStart] = null then null
        else if [S3BStart] = null then [S3AStart]
        else if [S3AStart] = null then [S3BStart]
        else List.Min({[S3AStart], [S3BStart]})),
    #"Added Key" = Table.AddColumn(#"Added S3Start", "ID", each Text.Combine({Text.From([Project ID], "en-US"), "-", [Unit ID]}), type text),
    // 가장 늦은 단계의 일자가 있는 상태를 현재 상태로 판정
    #"Added Status" = Table.AddColumn(#"Added Key", "Status", each
        if [Invoice] <> null then "Invoiced"
        else if [S3Complete] <> null then "S3 Complete"
        else if [S3Start] <> null then "S3 Start"
        else if [S2Complete] <> null then "S2 Complete"
        else if [S2Start] <> null then "S2 Start"
        else if [S1Complete] <> null then "S1 Complete"
        else if [S0End] <> null then "S0 Complete"
        else if [S0Start] <> null then "S0 Start"
        else "Waiting production"),
    #"Added StatusIndex" = Table.AddColumn(#"Added Status", "StatusIndex", each
        List.PositionOf({"Waiting production","S0 Start","S0 Complete","S1 Complete","S2 Start","S2 Complete","S3 Start","S3 Complete","Invoiced"}, [Status]))
in
    #"Added StatusIndex"

// ===== CustPlan: 주차별 고객 계획 (wide → long) =====
let
    Source = Excel.Workbook(Web.Contents("<SharePoint>/CustPlan Invoice.xlsx"), null, true),
    Sheet = Source{[Item="CustPlan",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Sheet, [PromoteAllScalars=true]),
    #"Replaced Null" = Table.ReplaceValue(#"Promoted Headers", null, 0, Replacer.ReplaceValue, List.Transform({1..52}, Text.From)),
    #"Unpivoted" = Table.UnpivotOtherColumns(#"Replaced Null", {"Project Name", "Total", "Unit Type"}, "week", "OTD")
in
    #"Unpivoted"

// ===== InvoiceTarget / InvoiceActual: 월별 청구 (wide → long) =====
let
    Source = Excel.Workbook(Web.Contents("<SharePoint>/CustPlan Invoice.xlsx"), null, true),
    Sheet = Source{[Item="Invoice table",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Sheet, [PromoteAllScalars=true]),
    Months = {"January","February","March","April","May","June","July","August","September","October","November","December"},
    #"Replaced Null" = Table.ReplaceValue(#"Promoted Headers", null, 0, Replacer.ReplaceValue, Months),
    #"Unpivoted" = Table.UnpivotOtherColumns(#"Replaced Null", {"Project Name", "Unit Type"}, "Month", "Inv Target"),
    #"Added Month_num" = Table.AddColumn(#"Unpivoted", "Month_num", each List.PositionOf(Months, [Month]) + 1)
in
    #"Added Month_num"
