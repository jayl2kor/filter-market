import DesignSystem
import FirebaseFunctions
import Foundation
import StoreKit
import SwiftUI

struct PaywallSingleScreen: View {
    let filterID: String

    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var walletStore: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var filterTitle: String = "필터"
    @State private var priceCoins: Int = 0
    @State private var loadError: String?
    @State private var isProcessing = false
    @State private var purchaseError: String?
    @State private var showInsufficient = false
    @State private var didPurchase = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                titleSection
                priceCard
                cta
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("필터 구매")
        .navigationBarTitleDisplayMode(.inline)
        .alert("결제 오류", isPresented: errorBinding, actions: {
            Button("확인", role: .cancel) { purchaseError = nil }
        }, message: { Text(purchaseError ?? "") })
        .navigationDestination(isPresented: $showInsufficient) {
            InsufficientBalanceScreen(filterID: filterID, requiredCoins: priceCoins, currentBalance: walletStore.coinBalance)
        }
        .navigationDestination(isPresented: $didPurchase) {
            FilterAfterDownloadScreen(filterID: filterID)
        }
        .task {
            await loadFilterDetail()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(filterTitle).font(Font.fmTitleLarge).foregroundStyle(FMColors.Text.primary)
            if let loadError {
                Text(loadError).font(Font.fmCaption).foregroundStyle(FMColors.Semantic.error)
            }
        }
    }

    @ViewBuilder
    private var priceCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Text("가격").font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
                Spacer()
                Text(isIncludedWithPro ? "Pro 멤버십에 포함" : "\(priceCoins.formatted()) 코인")
                    .font(Font.fmHeadline)
                    .foregroundStyle(isIncludedWithPro ? FMColors.Accent.primary : FMColors.Text.primary)
            }
            Rectangle().fill(FMColors.Border.subtle).frame(height: 0.5)
            HStack {
                Text("현재 잔액").font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
                Spacer()
                Text("\(walletStore.coinBalance.formatted()) 코인")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
            }
            HStack {
                Text("결제 후 잔액").font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
                Spacer()
                let after = isIncludedWithPro ? walletStore.coinBalance : walletStore.coinBalance - priceCoins
                Text(isIncludedWithPro ? "\(after.formatted()) 코인 · 차감 없음" : "\(after.formatted()) 코인")
                    .font(Font.fmCaption)
                    .foregroundStyle(after < 0 ? FMColors.Semantic.error : FMColors.Text.secondary)
            }
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private var cta: some View {
        VStack(spacing: Sp.sm) {
            FMButton(
                isIncludedWithPro ? "Pro로 다운로드" : "구매하기",
                icon: isIncludedWithPro ? "sparkles" : "circle.hexagongrid.circle.fill",
                variant: .primary,
                size: .lg,
                isLoading: isProcessing
            ) {
                Task { await purchase() }
            }
            .disabled(isProcessing || (priceCoins == 0 && !isIncludedWithPro))
            .accessibilityIdentifier("filter.purchase.confirm")

            NavigationLink(value: AppRoute.proSubscription) {
                HStack(spacing: Sp.xs) {
                    Image(systemName: "sparkles")
                    Text("Pro 멤버십 보기")
                        .font(Font.fmHeadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                .foregroundStyle(FMColors.Text.primary)
                .padding(.horizontal, Sp.md)
                .frame(height: 52)
                .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(FMColors.Border.default, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filter.purchase.pro_upgrade")
        }
    }

    private var isIncludedWithPro: Bool {
        walletStore.isProActive && priceCoins > 0
    }

    private func loadFilterDetail() async {
        #if DEBUG
        if isUITesting {
            filterTitle = "테스트 필터"
            priceCoins = 120
            loadError = nil
            return
        }
        #endif

        do {
            let detail = try await FilterDetailLoaderScreen.fetchDetail(filterId: filterID)
            filterTitle = detail.title
            priceCoins = detail.priceCoins
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func purchase() async {
        guard !isProcessing else { return }
        Telemetry.log(
            .filterPurchaseAttempted,
            parameters: ["filter_id": filterID, "price_coins": priceCoins, "pro_included": isIncludedWithPro]
        )
        if isIncludedWithPro {
            isProcessing = true
            defer { isProcessing = false }
            do {
                if let filter = filterLibraryStore.filter(matching: filterID) {
                    try await filterLibraryStore.download(filter)
                } else {
                    try await filterLibraryStore.download(filterID: filterID)
                }
                Telemetry.log(
                    .filterPurchaseSucceeded,
                    parameters: ["filter_id": filterID, "price_coins": 0, "pro_included": true]
                )
                didPurchase = true
            } catch {
                Telemetry.log(.filterPurchaseFailed, parameters: ["filter_id": filterID, "reason": "pro_download_error"])
                Telemetry.record(error: error, context: ["where": "proIncludedDownload", "filter_id": filterID])
                purchaseError = error.localizedDescription
            }
            return
        }
        if walletStore.coinBalance < priceCoins {
            Telemetry.log(.filterPurchaseInsufficient, parameters: ["filter_id": filterID, "price_coins": priceCoins, "balance": walletStore.coinBalance])
            showInsufficient = true
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("purchaseFilter")
            _ = try await callable.call(["filterId": filterID])
            // (#31) 구매 성공 → 자동 다운로드 마크 + 잔액 차감 (낙관적). filterAfterDownload로 이동.
            walletStore.creditCoinsOptimistically(-priceCoins)  // 음수 가산으로 차감
            if let filter = filterLibraryStore.filter(matching: filterID) {
                try? await filterLibraryStore.download(filter)
            }
            Telemetry.log(.filterPurchaseSucceeded, parameters: ["filter_id": filterID, "price_coins": priceCoins])
            didPurchase = true
        } catch let error as NSError where error.localizedDescription.contains("insufficient_balance") {
            Telemetry.log(.filterPurchaseInsufficient, parameters: ["filter_id": filterID, "price_coins": priceCoins])
            showInsufficient = true
        } catch {
            Telemetry.log(.filterPurchaseFailed, parameters: ["filter_id": filterID, "reason": "callable_error"])
            Telemetry.record(error: error, context: ["where": "purchaseFilter", "filter_id": filterID])
            purchaseError = error.localizedDescription
        }
    }
}

struct ProSubscriptionScreen: View {
    @EnvironmentObject private var walletStore: WalletStore
    @StateObject private var storeKit = StoreKitManager()
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseError: String?
    @State private var processingProductID: String?
    @State private var navigateToStatus = false
    @State private var selectedPlan: ProPlan = .yearly

    private enum ProPlan: String, CaseIterable, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly: "월간"
            case .yearly: "연간"
            }
        }

        var productID: String {
            switch self {
            case .monthly: IAPProductIDs.proMonthly
            case .yearly: IAPProductIDs.proYearly
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                header
                planToggle
                #if DEBUG
                if isUITesting {
                    testSubscriptionList
                } else {
                    subscriptionProductsContent
                }
                #else
                subscriptionProductsContent
                #endif
                invoiceLink
                policy
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("Pro 멤버십")
        .navigationBarTitleDisplayMode(.inline)
        .alert("결제 오류", isPresented: errorBinding, actions: {
            Button("확인", role: .cancel) { purchaseError = nil }
        }, message: { Text(purchaseError ?? "") })
        .navigationDestination(isPresented: $navigateToStatus) {
            ProStatusScreen()
        }
        .task {
            if storeKit.products.isEmpty {
                await storeKit.loadProducts(ids: IAPProductIDs.proIDs)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    private var orderedProducts: [StoreKit.Product] {
        storeKit.products.sorted { lhs, rhs in
            if lhs.id == selectedPlan.productID { return true }
            if rhs.id == selectedPlan.productID { return false }
            return lhs.id < rhs.id
        }
    }

    @ViewBuilder
    private var subscriptionProductsContent: some View {
        if storeKit.products.isEmpty {
            if let lastError = storeKit.lastError {
                Text(lastError).font(Font.fmCaption).foregroundStyle(FMColors.Semantic.error)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        } else {
            ForEach(orderedProducts, id: \.id) { product in
                productCard(product: product)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Label("Pro 혜택", systemImage: "sparkles")
                .font(Font.fmHeadline)
                .foregroundStyle(FMColors.Accent.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text("• 광고 없이 사용").font(Font.fmBody)
                Text("• 메이커 분석 도구").font(Font.fmBody)
                Text("• Pro 전용 필터 무제한").font(Font.fmBody)
            }
            .foregroundStyle(FMColors.Text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private var planToggle: some View {
        Picker("플랜", selection: $selectedPlan) {
            ForEach(ProPlan.allCases) { plan in
                Text(plan.title).tag(plan)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("pro.plan.toggle")
    }

    @ViewBuilder
    private var testSubscriptionList: some View {
        VStack(spacing: Sp.sm) {
            testSubscriptionCard(productID: IAPProductIDs.proMonthly, title: "월간", subtitle: "월 단위로 결제", price: "테스트 KRW 4,900")
            testSubscriptionCard(productID: IAPProductIDs.proYearly, title: "연간", subtitle: "12개월 - 가장 합리적", price: "테스트 KRW 39,000")
        }
    }

    @ViewBuilder
    private func testSubscriptionCard(productID: String, title: String, subtitle: String, price: String) -> some View {
        Button {
            navigateToStatus = true
        } label: {
            HStack(spacing: Sp.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(subtitle)
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Text(price)
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro.subscribe.\(productID)")
    }

    @ViewBuilder
    private var invoiceLink: some View {
        NavigationLink(value: AppRoute.refundRequest(orderId: nil)) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("영수증 및 환불 문의")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .font(Font.fmBody)
            .foregroundStyle(FMColors.Text.primary)
            .padding(Sp.md)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro.invoice")
    }

    @ViewBuilder
    private func productCard(product: StoreKit.Product) -> some View {
        let isProcessing = processingProductID == product.id
        Button {
            Task { await purchase(product) }
        } label: {
            HStack(spacing: Sp.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.id == IAPProductIDs.proYearly ? "연간" : "월간")
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(product.id == IAPProductIDs.proYearly ? "12개월 — 가장 합리적" : "월 단위로 결제")
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                if isProcessing {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Text.primary)
                }
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing || storeKit.isProcessing)
        .accessibilityIdentifier("pro.subscribe.\(product.id)")
    }

    private func purchase(_ product: StoreKit.Product) async {
        processingProductID = product.id
        defer { processingProductID = nil }
        let outcome = await storeKit.purchase(product)
        switch outcome {
        case .success:
            // (#27) 낙관적 Pro 활성화 — listener 도착 전이라도 ProStatusScreen으로 즉시 이동.
            walletStore.markProActiveOptimistically()
            navigateToStatus = true
        case .userCancelled:
            break
        case .pending:
            purchaseError = "결제가 보류 중입니다."
        case .failed(let message):
            purchaseError = message
            walletStore.lastPaymentErrorMessage = message  // (#41) PaymentFailedScreen 진입 시 활용
        }
    }

    @ViewBuilder
    private var policy: some View {
        Text("Apple ID로 결제. 자동 갱신은 App Store 설정에서 관리할 수 있습니다.")
            .font(Font.fmCaption)
            .foregroundStyle(FMColors.Text.tertiary)
    }
}

struct ProStatusScreen: View {
    @EnvironmentObject private var walletStore: WalletStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                statusCard
                manageLink
                invoiceLink
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("Pro 상태")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(FMColors.Accent.primary)
                Text(walletStore.isProActive ? "Pro 활성" : "Pro 비활성")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
            }
            Text(walletStore.isProActive
                 ? "현재 Pro 멤버십이 활성화되어 있습니다."
                 : "Pro에 가입하지 않았습니다.")
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private var manageLink: some View {
        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
            HStack {
                Image(systemName: "arrow.up.right.square")
                Text("App Store에서 구독 관리")
            }
            .font(Font.fmBody)
            .foregroundStyle(FMColors.Accent.primary)
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .accessibilityIdentifier("pro.cancel")
    }

    @ViewBuilder
    private var invoiceLink: some View {
        NavigationLink(value: AppRoute.refundRequest(orderId: nil)) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("영수증 및 환불 문의")
            }
            .font(Font.fmBody)
            .foregroundStyle(FMColors.Text.primary)
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro.invoice")
    }
}

struct OrdersHistoryScreen: View {
    @StateObject private var ledger = WalletLedgerStore()

    var body: some View {
        VStack(spacing: 0) {
            let orders = ledger.entries.filter { $0.kind == .purchase }
            if orders.isEmpty {
                FMEmptyState(.emptyMarket)
                    .padding(.horizontal, Sp.md)
                    .accessibilityIdentifier("orders.empty")
            } else {
                List {
                    ForEach(orders) { entry in
                        orderRow(entry)
                    }
                }
                .listStyle(.plain)
                .refreshable { await ledger.refresh() }
            }
            orderSupportActions
                .padding(.horizontal, Sp.md)
                .padding(.vertical, Sp.md)
            Spacer(minLength: 0)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("주문 내역")
        .navigationBarTitleDisplayMode(.inline)
        .task { ledger.start() }
    }

    private func orderRow(_ entry: WalletLedgerEntry) -> some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(FMColors.Text.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.relatedItemTitle ?? "필터 구매").font(Font.fmBody)
                    Text(entry.createdAt, style: .date).font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                Spacer()
                Text("\(entry.amount.formatted())")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
            }

            NavigationLink(value: AppRoute.refundRequest(orderId: entry.id)) {
                Label("이 주문 환불 요청", systemImage: "arrow.uturn.backward.circle")
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Accent.primary)
            }
            .accessibilityIdentifier("orders.refund_request.\(entry.id)")
        }
        .padding(.vertical, Sp.xs)
    }

    @ViewBuilder
    private var orderSupportActions: some View {
        VStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.walletTransactions) {
                workflowRouteRow("거래 내역 보기", icon: "list.bullet.rectangle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.transactions")

            NavigationLink(value: AppRoute.refundRequest(orderId: nil)) {
                workflowRouteRow("환불 요청", icon: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.refund_request")
        }
    }
}

struct WalletScreen: View {
    @EnvironmentObject private var walletStore: WalletStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                balanceCard
                actions
                policyNote
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("지갑")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("코인 잔액")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
            HStack(alignment: .firstTextBaseline, spacing: Sp.xs) {
                Image(systemName: "circle.hexagongrid.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                Text("\(walletStore.coinBalance.formatted())")
                    .font(Font.fmTitleLarge)
                    .foregroundStyle(FMColors.Text.primary)
                Text("코인")
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.secondary)
            }
            if walletStore.isProActive {
                Label("Pro 멤버십 활성", systemImage: "sparkles")
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Accent.primary)
                    .padding(.top, Sp.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .accessibilityIdentifier("wallet.balance")
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 0) {
            walletAction(icon: "plus.circle.fill", title: "충전하기", subtitle: "코인 패키지로 결제", route: .walletTopup)
            divider
            walletAction(icon: "list.bullet.rectangle", title: "거래 내역", subtitle: "충전 / 사용 / 환불 기록", route: .walletTransactions)
            divider
            walletAction(icon: "sparkles", title: walletStore.isProActive ? "Pro 상태" : "Pro 시작",
                         subtitle: walletStore.isProActive ? "현재 구독 정보" : "Pro 멤버십 가입",
                         route: walletStore.isProActive ? .proStatus : .proSubscription)
            divider
            walletAction(icon: "doc.text.magnifyingglass", title: "주문 내역", subtitle: "필터 구매 내역", route: .ordersHistory)
        }
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private func walletAction(icon: String, title: String, subtitle: String, route: AppRoute) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Sp.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Font.fmBody).foregroundStyle(FMColors.Text.primary)
                    Text(subtitle).font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .padding(Sp.md)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wallet.action.\(route.title)")
    }

    private var divider: some View {
        Rectangle()
            .fill(FMColors.Border.subtle)
            .frame(height: 0.5)
            .padding(.leading, Sp.lg)
    }

    @ViewBuilder
    private var policyNote: some View {
        Text("코인은 moodit 안에서만 사용 가능하며 환불은 Apple 정책 + 도움말 환불 폼을 통해 처리합니다 (ADR-0006).")
            .font(Font.fmCaption)
            .foregroundStyle(FMColors.Text.tertiary)
            .padding(.horizontal, Sp.xs)
    }
}

struct WalletTopupScreen: View {
    @EnvironmentObject private var walletStore: WalletStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager()

    @State private var purchasingProductID: String?
    @State private var purchaseError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                header
                #if DEBUG
                if isUITesting {
                    testPackageList
                } else {
                    topupProductsContent
                }
                #else
                topupProductsContent
                #endif
                policyNote
                topupSupportActions
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("코인 충전")
        .navigationBarTitleDisplayMode(.inline)
        .alert("결제 오류", isPresented: errorBinding, actions: {
            Button("확인", role: .cancel) { purchaseError = nil }
        }, message: {
            Text(purchaseError ?? "")
        })
        .task {
            if storeKit.products.isEmpty {
                await storeKit.loadProducts(ids: IAPProductIDs.coinIDs)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    @ViewBuilder
    private var topupProductsContent: some View {
        if storeKit.products.isEmpty {
            if let lastError = storeKit.lastError {
                loadErrorBanner(lastError)
            } else {
                loadingBanner
            }
        } else {
            packageList
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("현재 잔액")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
            HStack(spacing: Sp.xs) {
                Image(systemName: "circle.hexagongrid.circle.fill")
                    .foregroundStyle(FMColors.Accent.primary)
                Text("\(walletStore.coinBalance.formatted()) 코인")
                    .font(Font.fmTitle)
                    .foregroundStyle(FMColors.Text.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private var testPackageList: some View {
        VStack(spacing: Sp.sm) {
            testPackageRow(productID: IAPProductIDs.coins100, displayPrice: "테스트 KRW 1,200")
            testPackageRow(productID: IAPProductIDs.coins550, displayPrice: "테스트 KRW 5,900")
            testPackageRow(productID: IAPProductIDs.coins1200, displayPrice: "테스트 KRW 12,000")
            testPackageRow(productID: IAPProductIDs.coins3000, displayPrice: "테스트 KRW 29,000")
        }
    }

    @ViewBuilder
    private func testPackageRow(productID: String, displayPrice: String) -> some View {
        let coins = IAPProductIDs.coinAmount(for: productID) ?? 0
        let bonusLabel = bonusLabel(for: productID)
        Button {
            FMHaptic.light.play()
            if let credit = IAPProductIDs.coinAmount(for: productID) {
                walletStore.creditCoinsOptimistically(credit)
            }
            dismiss()
        } label: {
            HStack(spacing: Sp.md) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Sp.xs) {
                        Text("\(coins.formatted()) 코인")
                            .font(Font.fmHeadline)
                            .foregroundStyle(FMColors.Text.primary)
                        if let bonusLabel {
                            Text(bonusLabel)
                                .font(Font.fmCaption.weight(.semibold))
                                .foregroundStyle(FMColors.Accent.primary)
                                .lineLimit(1)
                                .padding(.horizontal, Sp.xs)
                                .padding(.vertical, 2)
                                .background(FMColors.Accent.primary.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                    Text(packageLabel(for: productID))
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Text(displayPrice)
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 112, alignment: .trailing)
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 76)
            .contentShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(CoinPackageRowButtonStyle())
        .accessibilityIdentifier("wallet.topup.package.\(productID)")
    }

    @ViewBuilder
    private var packageList: some View {
        VStack(spacing: Sp.sm) {
            ForEach(storeKit.products, id: \.id) { product in
                packageRow(product: product)
            }
        }
    }

    @ViewBuilder
    private func packageRow(product: StoreKit.Product) -> some View {
        let coins = IAPProductIDs.coinAmount(for: product.id) ?? 0
        let bonusLabel = bonusLabel(for: product.id)
        let isProcessing = purchasingProductID == product.id
        Button {
            FMHaptic.light.play()
            Task { await initiatePurchase(product) }
        } label: {
            HStack(spacing: Sp.md) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Sp.xs) {
                        Text("\(coins.formatted()) 코인")
                            .font(Font.fmHeadline)
                            .foregroundStyle(FMColors.Text.primary)
                        if let bonusLabel {
                            Text(bonusLabel)
                                .font(Font.fmCaption.weight(.semibold))
                                .foregroundStyle(FMColors.Accent.primary)
                                .lineLimit(1)
                                .padding(.horizontal, Sp.xs)
                                .padding(.vertical, 2)
                                .background(FMColors.Accent.primary.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                    Text(packageLabel(for: product.id))
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                if isProcessing {
                    ProgressView()
                        .frame(width: 112, alignment: .trailing)
                } else {
                    Text(product.displayPrice)
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Text.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 112, alignment: .trailing)
                }
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 76)
            .contentShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(CoinPackageRowButtonStyle())
        .disabled(isProcessing || storeKit.isProcessing)
        .accessibilityIdentifier("wallet.topup.package.\(product.id)")
    }

    private func packageLabel(for productId: String) -> String {
        switch productId {
        case IAPProductIDs.coins100: "Starter — 가벼운 시도"
        case IAPProductIDs.coins550: "Popular — 가장 인기"
        case IAPProductIDs.coins1200: "Best Value — 효율적"
        case IAPProductIDs.coins3000: "Pro Pack — 가장 큰 보너스"
        default: "코인 패키지"
        }
    }

    private func bonusLabel(for productId: String) -> String? {
        switch productId {
        case IAPProductIDs.coins550: "+10%"
        case IAPProductIDs.coins1200: "+20%"
        case IAPProductIDs.coins3000: "+30%"
        default: nil
        }
    }

    private func initiatePurchase(_ product: StoreKit.Product) async {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        let outcome = await storeKit.purchase(product)
        switch outcome {
        case .success:
            if let creditResult = storeKit.lastCoinCreditResult {
                walletStore.reconcileCoinBalance(creditResult.balance)
            } else if let credit = IAPProductIDs.coinAmount(for: product.id) {
                // Fallback for local StoreKit/test paths where callable response parsing is unavailable.
                walletStore.creditCoinsOptimistically(credit)
            }
            dismiss()
        case .userCancelled:
            break
        case .pending:
            purchaseError = "결제가 보류 중입니다. 약관 승인 후 자동 완료됩니다."
        case .failed(let message):
            purchaseError = message
            walletStore.lastPaymentErrorMessage = message  // (#41) PaymentFailedScreen 진입 시 활용
        }
    }

    @ViewBuilder
    private var loadingBanner: some View {
        VStack(spacing: Sp.sm) {
            ProgressView()
            Text("패키지를 불러오는 중…")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(Sp.md)
    }

    @ViewBuilder
    private func loadErrorBanner(_ message: String) -> some View {
        VStack(spacing: Sp.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(FMColors.Semantic.error)
            Text("패키지를 불러오지 못했어요")
                .font(Font.fmHeadline)
                .foregroundStyle(FMColors.Text.primary)
            Text(message)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
            FMButton("다시 시도", variant: .secondary, size: .md) {
                Task { await storeKit.loadProducts(ids: IAPProductIDs.coinIDs) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Sp.md)
    }

    @ViewBuilder
    private var policyNote: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("Apple ID 결제. 충전한 코인은 moodit 내에서만 사용 가능하며, 환불은 Apple 정책 + 도움말 환불 폼을 통해 처리합니다.")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.tertiary)
            Text("결제를 계속하면 코인 약관과 환불 정책에 동의하는 것으로 간주됩니다 (ADR-0006).")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.tertiary)
        }
        .padding(.horizontal, Sp.xs)
    }

    @ViewBuilder
    private var topupSupportActions: some View {
        VStack(spacing: Sp.sm) {
            Button {
                Task { await storeKit.restore() }
            } label: {
                Label("구매 복원", systemImage: "arrow.clockwise.circle")
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(maxWidth: .infinity)
                    .padding(Sp.md)
                    .background(FMColors.Background.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: R.lg))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.topup.restore")

            NavigationLink(value: AppRoute.paymentFailed) {
                Label("결제 문제 해결", systemImage: "exclamationmark.triangle")
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(Sp.md)
                    .background(FMColors.Background.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: R.lg))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.topup.failed_demo")
        }
    }
}

private struct CoinPackageRowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? FMColors.Background.bg3 : FMColors.Background.bg2,
                in: RoundedRectangle(cornerRadius: R.lg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.fmFast.reducedIfNeeded(reduceMotion), value: configuration.isPressed)
    }
}

struct WalletTransactionsScreen: View {
    @StateObject private var ledger = WalletLedgerStore()
    @State private var selectedKind: WalletLedgerEntry.Kind?

    var body: some View {
        VStack(spacing: 0) {
            transactionFilter
                .padding(.horizontal, Sp.md)
                .padding(.top, Sp.sm)

            if filteredEntries.isEmpty {
                if let loadError = ledger.loadError {
                    errorView(loadError)
                } else if ledger.isLoading {
                    loadingView
                } else {
                    transactionEmptyState
                        .padding(.horizontal, Sp.md)
                        .accessibilityIdentifier("wallet.transactions.empty")
                }
                transactionSupportActions
                    .padding(.horizontal, Sp.md)
                    .padding(.top, Sp.md)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        ledgerRow(entry: entry)
                    }
                }
                .listStyle(.plain)
                .refreshable { await ledger.refresh() }
            }
            Spacer(minLength: 0)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("거래 내역")
        .navigationBarTitleDisplayMode(.inline)
        .task { ledger.start() }
    }

    private var filteredEntries: [WalletLedgerEntry] {
        guard let selectedKind else { return ledger.entries }
        return ledger.entries.filter { $0.kind == selectedKind }
    }

    @ViewBuilder
    private var transactionFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.xs) {
                transactionFilterChip("전체", isSelected: selectedKind == nil) {
                    FMHaptic.light.play()
                    selectedKind = nil
                }
                ForEach([WalletLedgerEntry.Kind.topup, .purchase, .refund, .bonus], id: \.self) { kind in
                    transactionFilterChip(label(for: kind), isSelected: selectedKind == kind) {
                        FMHaptic.light.play()
                        selectedKind = kind
                    }
                }
            }
            .padding(.vertical, Sp.xs)
        }
        .accessibilityIdentifier("wallet.tx.filter.cat")
    }

    @ViewBuilder
    private func transactionFilterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(isSelected ? Font.fmCaption.weight(.semibold) : Font.fmCaption)
                .foregroundStyle(isSelected ? FMColors.Text.inverse : FMColors.Text.tertiary)
                .lineLimit(1)
                .padding(.horizontal, Sp.sm)
                .frame(minHeight: 32)
                .background(isSelected ? FMColors.Accent.primary : Color.clear, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : FMColors.Border.default, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }

    @ViewBuilder
    private var transactionEmptyState: some View {
        VStack(spacing: Sp.md) {
            FMEmptyStateIllustration(.downloads, size: 96)
                .frame(width: 96, height: 96)

            VStack(spacing: Sp.xs) {
                Text(selectedKind == nil ? "아직 거래 내역이 없어요" : "\(label(for: selectedKind ?? .unknown)) 내역이 없어요")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
                    .multilineTextAlignment(.center)
                Text(selectedKind == nil ? "코인을 충전하거나 필터를 구매하면 이곳에 기록돼요." : "다른 거래 유형을 선택하거나 전체 내역을 확인해 보세요.")
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.secondary)
                    .multilineTextAlignment(.center)
            }

            if ledger.entries.isEmpty {
                NavigationLink(value: AppRoute.walletTopup) {
                    Text("코인 충전하기")
                        .font(Font.fmCallout.weight(.semibold))
                        .foregroundStyle(FMColors.Text.inverse)
                        .frame(maxWidth: 240)
                        .frame(height: 44)
                        .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wallet.transactions.empty.topup")
            } else {
                Button {
                    FMHaptic.light.play()
                    selectedKind = nil
                } label: {
                    Text("전체 거래 보기")
                        .font(Font.fmCallout.weight(.semibold))
                        .foregroundStyle(FMColors.Accent.primary)
                        .frame(maxWidth: 240)
                        .frame(height: 44)
                        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                        .overlay {
                            RoundedRectangle(cornerRadius: R.md)
                                .strokeBorder(FMColors.Border.default, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wallet.transactions.empty.clearFilter")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Sp.xxl)
    }

    @ViewBuilder
    private var transactionSupportActions: some View {
        VStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.ordersHistory) {
                workflowRouteRow("주문 내역", icon: "cart")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("orders.history")

            NavigationLink(value: AppRoute.refundRequest(orderId: nil)) {
                workflowRouteRow("환불 요청", icon: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.refund_request")
        }
    }

    @ViewBuilder
    private func ledgerRow(entry: WalletLedgerEntry) -> some View {
        HStack(spacing: Sp.md) {
            Image(systemName: iconName(for: entry.kind))
                .font(.system(size: 18))
                .foregroundStyle(iconColor(for: entry.kind))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label(for: entry.kind))
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
                if let item = entry.relatedItemTitle, !item.isEmpty {
                    Text(item)
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Text(entry.createdAt, style: .date)
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            Spacer()
            Text(amountText(entry.amount))
                .font(Font.fmHeadline)
                .monospacedDigit()
                .foregroundStyle(amountColor(entry.amount))
        }
        .padding(.vertical, Sp.xs)
        .accessibilityIdentifier("wallet.transactions.row.\(entry.id)")
    }

    private func iconName(for kind: WalletLedgerEntry.Kind) -> String {
        switch kind {
        case .topup: "plus.circle.fill"
        case .purchase: "cart.fill"
        case .refund: "arrow.uturn.backward.circle"
        case .bonus: "gift.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func iconColor(for kind: WalletLedgerEntry.Kind) -> Color {
        switch kind {
        case .topup, .bonus: FMColors.Accent.primary
        case .purchase: FMColors.Text.secondary
        case .refund: FMColors.Semantic.error
        case .unknown: FMColors.Text.tertiary
        }
    }

    private func label(for kind: WalletLedgerEntry.Kind) -> String {
        switch kind {
        case .topup: "충전"
        case .purchase: "사용"
        case .refund: "환불"
        case .bonus: "보너스"
        case .unknown: "기록"
        }
    }

    private func amountText(_ amount: Int) -> String {
        amount > 0 ? "+\(amount.formatted())" : "\(amount.formatted())"
    }

    private func amountColor(_ amount: Int) -> Color {
        amount > 0 ? FMColors.Accent.primary : FMColors.Text.primary
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Sp.md) {
            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: Sp.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(FMColors.Semantic.error)
            Text("거래 내역을 불러오지 못했어요")
                .font(Font.fmHeadline)
                .foregroundStyle(FMColors.Text.primary)
            Text(message)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Sp.md)
    }
}

struct InsufficientBalanceScreen: View {
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var walletStore: WalletStore
    @Environment(\.dismiss) private var dismiss

    let filterID: String
    var requiredCoins: Int = 0
    var currentBalance: Int = 0

    @State private var isRetryingPurchase = false
    @State private var didCompletePurchase = false
    @State private var purchaseError: String?
    @State private var didAutoRetry = false

    var body: some View {
        VStack(spacing: Sp.lg) {
            Spacer()
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(FMColors.Semantic.error)
            Text("코인이 부족해요")
                .font(Font.fmTitle)
                .foregroundStyle(FMColors.Text.primary)
            if requiredCoins > 0 {
                let shortfall = max(requiredCoins - displayedBalance, 0)
                Text("\(shortfall.formatted())코인 부족")
                    .font(Font.fmBody)
                    .foregroundStyle(shortfall == 0 ? FMColors.Accent.primary : FMColors.Text.secondary)
                Text("현재 잔액 \(displayedBalance.formatted())코인 · 필터 \(filterIDLabel)")
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            VStack(spacing: Sp.sm) {
                if canRetryPurchase {
                    FMButton(
                        "지금 구매하기",
                        icon: "creditcard.fill",
                        variant: .primary,
                        size: .lg,
                        isLoading: isRetryingPurchase
                    ) {
                        Task { await retryPurchase() }
                    }
                    .disabled(isRetryingPurchase)
                    .accessibilityIdentifier("insufficient.purchase.retry")
                }

                NavigationLink(value: AppRoute.walletTopup) {
                    Text(canRetryPurchase ? "추가 충전하기" : "충전하기")
                        .font(Font.fmHeadline)
                        .foregroundStyle(canRetryPurchase ? FMColors.Accent.primary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Sp.md)
                        .background(canRetryPurchase ? FMColors.Background.bg2 : FMColors.Accent.primary)
                        .clipShape(RoundedRectangle(cornerRadius: R.lg))
                        .overlay {
                            if canRetryPurchase {
                                RoundedRectangle(cornerRadius: R.lg)
                                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
                            }
                        }
                }
                .accessibilityIdentifier("insufficient.topup")
            }
            Button("취소") {
                dismiss()
            }
            .font(Font.fmBody)
            .foregroundStyle(FMColors.Text.secondary)
            .accessibilityIdentifier("wallet.insufficient.cancel")
            Spacer()
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("잔액 부족")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $didCompletePurchase) {
            FilterAfterDownloadScreen(filterID: filterID)
        }
        .alert("구매 오류", isPresented: errorBinding, actions: {
            Button("확인", role: .cancel) { purchaseError = nil }
        }, message: { Text(purchaseError ?? "") })
        .task {
            await retryIfBalanceIsReady()
        }
        .onChange(of: walletStore.coinBalance) { _, _ in
            Task { await retryIfBalanceIsReady() }
        }
    }

    private var displayedBalance: Int {
        walletStore.coinBalance == 0 && currentBalance > 0 ? currentBalance : walletStore.coinBalance
    }

    private var canRetryPurchase: Bool {
        requiredCoins > 0 && displayedBalance >= requiredCoins
    }

    private var filterIDLabel: String {
        UUID(uuidString: filterID) == nil ? filterID : String(filterID.prefix(8))
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    private func retryIfBalanceIsReady() async {
        guard canRetryPurchase, !didAutoRetry, !isRetryingPurchase, !didCompletePurchase else { return }
        didAutoRetry = true
        await retryPurchase()
    }

    private func retryPurchase() async {
        guard !isRetryingPurchase, canRetryPurchase else { return }
        isRetryingPurchase = true
        defer { isRetryingPurchase = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("purchaseFilter")
            _ = try await callable.call(["filterId": filterID])
            walletStore.creditCoinsOptimistically(-requiredCoins)
            if let filter = filterLibraryStore.filter(matching: filterID) {
                try? await filterLibraryStore.download(filter)
            } else {
                try? await filterLibraryStore.download(filterID: filterID)
            }
            Telemetry.log(.filterPurchaseSucceeded, parameters: ["filter_id": filterID, "price_coins": requiredCoins, "source": "insufficient_balance_retry"])
            didCompletePurchase = true
        } catch let error as NSError where error.localizedDescription.contains("insufficient_balance") {
            didAutoRetry = false
            Telemetry.log(.filterPurchaseInsufficient, parameters: ["filter_id": filterID, "price_coins": requiredCoins, "balance": walletStore.coinBalance])
            purchaseError = "아직 코인이 부족합니다."
        } catch {
            didAutoRetry = false
            Telemetry.log(.filterPurchaseFailed, parameters: ["filter_id": filterID, "reason": "insufficient_retry_error"])
            Telemetry.record(error: error, context: ["where": "insufficientBalanceRetry", "filter_id": filterID])
            purchaseError = error.localizedDescription
        }
    }
}

struct PaymentFailedScreen: View {
    @EnvironmentObject private var walletStore: WalletStore
    @Environment(\.openURL) private var openURL
    @StateObject private var storeKit = StoreKitManager()
    /// (#41) walletStore.lastPaymentErrorMessage 우선, fallback은 일반 텍스트.
    private var lastErrorMessage: String {
        walletStore.lastPaymentErrorMessage ?? "결제가 처리되지 않았습니다."
    }

    var body: some View {
        VStack(spacing: Sp.lg) {
            Spacer()
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 48))
                .foregroundStyle(FMColors.Semantic.error)
            Text("결제 실패")
                .font(Font.fmTitle)
                .foregroundStyle(FMColors.Text.primary)
            Text(lastErrorMessage)
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Sp.md)
            VStack(spacing: Sp.sm) {
                NavigationLink(value: AppRoute.walletTopup) {
                    Text("다시 시도")
                        .font(Font.fmHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Sp.md)
                        .background(FMColors.Accent.primary)
                        .clipShape(RoundedRectangle(cornerRadius: R.lg))
                }
                .accessibilityIdentifier("wallet.topup.retry")

                Button {
                    Task { await storeKit.restore() }
                } label: {
                    Text("구매 복원")
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Accent.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Sp.md)
                }
                .accessibilityIdentifier("payment.failed.restore")

                Button("지원팀에 문의") {
                    openURL(URL(string: "mailto:support@moodit.app?subject=Payment%20Issue")!)
                }
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
                .accessibilityIdentifier("wallet.topup.support")
            }
            Spacer()
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("결제 실패")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // (#41 후속) 화면 떠날 때 에러 메시지 reset — 다음 진입 시 stale 에러 노출 방지.
            walletStore.lastPaymentErrorMessage = nil
        }
    }
}

struct RefundRequestScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var orderId: String = ""
    @State private var reason: String = ""
    @State private var isProcessing = false
    @State private var statusMessage: String?

    private let prefilledOrderId: String?
    private let maxReasonLength = 2_000

    init(prefilledOrderId: String? = nil) {
        self.prefilledOrderId = prefilledOrderId
        _orderId = State(initialValue: prefilledOrderId ?? "")
    }

    var body: some View {
        Form {
            Section(header: Text("주문 ID")) {
                if let prefilledOrderId {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prefilledOrderId)
                            .font(Font.fmCaption)
                            .foregroundStyle(FMColors.Text.primary)
                            .textSelection(.enabled)
                        Text("주문 내역에서 선택한 주문입니다.")
                            .font(Font.fmCaption)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    .accessibilityIdentifier("refund.orderId")
                } else {
                    TextField("orders/abc-123 형식", text: $orderId)
                        .textContentType(.URL)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .accessibilityIdentifier("refund.orderId")
                }
            }
            Section(header: Text("환불 사유"), footer: reasonFooter) {
                TextEditor(text: reasonBinding)
                    .frame(minHeight: 120)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.return)
                    .accessibilityIdentifier("refund.reason")
            }
            if let statusMessage {
                Section { Text(statusMessage).foregroundStyle(FMColors.Text.secondary) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("환불 요청 제출")
                    }
                }
                .disabled(isProcessing || normalizedOrderId.isEmpty || normalizedReason.isEmpty || reason.count > maxReasonLength)
                .accessibilityIdentifier("refund.submit")
            }
        }
        .navigationTitle("환불 요청")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var normalizedOrderId: String {
        orderId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var reasonBinding: Binding<String> {
        Binding(
            get: { reason },
            set: { reason = String($0.prefix(maxReasonLength)) }
        )
    }

    private var reasonFooter: some View {
        HStack {
            Text("최대 2000자")
            Spacer()
            Text("\(reason.count) / \(maxReasonLength)")
                .monospacedDigit()
                .foregroundStyle(reason.count > 1_900 ? FMColors.Semantic.warning : FMColors.Text.tertiary)
        }
    }

    private func submit() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("refundRequest")
            _ = try await callable.call(["orderId": normalizedOrderId, "reason": normalizedReason])
            statusMessage = "환불 요청이 접수되었습니다. 24시간 내 검토합니다."
            orderId = ""
            reason = ""
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            statusMessage = "오류: \(error.localizedDescription)"
        }
    }
}
