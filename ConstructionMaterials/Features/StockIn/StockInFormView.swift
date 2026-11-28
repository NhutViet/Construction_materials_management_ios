import SwiftUI

struct StockInFormView: View {
    let onCreated: (StockIn) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore

    @State private var materials: [Material] = []
    @State private var drafts: [StockInDraftItem] = []
    @State private var selectedMaterialId = ""
    @State private var quantity: Double = 1
    @State private var unitPrice: Double = 0

    @State private var isAddingNewMaterial = ProcessInfo.processInfo.environment["IOS_TEST_NEW_MATERIAL"] == "1"
    @State private var newMaterialName = ""
    @State private var newMaterialCategory = MaterialOptions.categories[0]
    @State private var newMaterialUnit = "cái"
    @State private var newMaterialPrice: Double = 0
    @State private var newMaterialMinStock: Double = 10
    @State private var newMaterialError: String?

    @State private var supplier = ""
    @State private var supplierPhone = ""
    @State private var supplierAddress = ""
    @State private var taxRate: Double = 0
    @State private var discountRate: Double = 0
    @State private var paidAmount: Double = 0
    @State private var notes = ""

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    private let materialService = MaterialService()
    private let service = StockInService()

    private var activeMaterials: [Material] {
        materials.filter(\.isAvailable)
    }

    private var selectedMaterial: Material? {
        activeMaterials.first { $0.id == selectedMaterialId }
    }

    private var subtotal: Double {
        roundMoney(drafts.reduce(0) { $0 + $1.total })
    }

    private var taxAmount: Double {
        roundMoney(subtotal * taxRate / 100)
    }

    private var discountAmount: Double {
        roundMoney(subtotal * discountRate / 100)
    }

    private var total: Double {
        roundMoney(subtotal + taxAmount - discountAmount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FormSection(title: "Nhà cung cấp") {
                        FormField(
                            title: "Tên nhà cung cấp",
                            placeholder: "Tên nhà cung cấp",
                            icon: "building.2.fill",
                            text: $supplier
                        )
                        FormField(
                            title: "Số điện thoại",
                            placeholder: "09xx xxx xxx",
                            icon: "phone.fill",
                            text: $supplierPhone,
                            keyboard: .phonePad
                        )
                        FormField(
                            title: "Địa chỉ",
                            placeholder: "Địa chỉ nhà cung cấp",
                            icon: "mappin.and.ellipse",
                            text: $supplierAddress,
                            axis: .vertical,
                            lineLimit: 1...3
                        )
                    }

                    FormSection(title: "Thêm mặt hàng") {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else {
                            Picker("Nguồn vật tư", selection: $isAddingNewMaterial) {
                                Text("Vật tư có sẵn").tag(false)
                                Text("Vật tư mới").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: isAddingNewMaterial) { _, isNew in
                                newMaterialError = nil
                                quantity = 1
                                if isNew {
                                    unitPrice = 0
                                } else if let material = selectedMaterial {
                                    unitPrice = material.importCost ?? material.priceValue
                                }
                            }

                            if isAddingNewMaterial {
                                FormField(
                                    title: "Tên vật tư *",
                                    placeholder: "Ví dụ: Xi măng Hà Tiên",
                                    icon: "shippingbox.fill",
                                    text: $newMaterialName
                                )
                                FormSelectField(
                                    title: "Danh mục",
                                    icon: "square.grid.2x2.fill",
                                    selection: $newMaterialCategory,
                                    options: MaterialOptions.categories
                                )
                                FormSelectField(
                                    title: "Đơn vị",
                                    icon: "ruler.fill",
                                    selection: $newMaterialUnit,
                                    options: MaterialOptions.units
                                )
                                FormNumberRow(
                                    title: "Giá bán",
                                    value: $newMaterialPrice,
                                    suffix: "đ",
                                    width: 108
                                )
                                FormNumberRow(
                                    title: "Tồn tối thiểu",
                                    value: $newMaterialMinStock,
                                    suffix: newMaterialUnit,
                                    width: 88
                                )
                                FormNumberRow(
                                    title: "Số lượng nhập",
                                    value: $quantity,
                                    suffix: newMaterialUnit,
                                    width: 88
                                )
                                FormNumberRow(
                                    title: "Giá nhập đợt này",
                                    value: $unitPrice,
                                    suffix: "/\(newMaterialUnit)",
                                    width: 100
                                )

                                if let newMaterialError {
                                    Text(newMaterialError)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.danger)
                                }

                                Button {
                                    addNewMaterialDraft()
                                } label: {
                                    Label("Thêm vật tư mới vào phiếu", systemImage: "plus.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                }
                                .foregroundStyle(.white)
                                .background(
                                    newMaterialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quantity <= 0
                                        ? Color.gray.opacity(0.4)
                                        : AppTheme.primary,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                )
                                .disabled(
                                    newMaterialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quantity <= 0
                                )

                                Text("Vật tư mới sẽ được tạo khi lưu phiếu nhập, kèm tồn kho vừa nhập.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else if activeMaterials.isEmpty {
                                Text("Chưa có vật tư đang hoạt động. Chuyển sang “Vật tư mới” để tạo.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                FormPickerRow(title: "Vật tư") {
                                    Picker("", selection: $selectedMaterialId) {
                                        Text("Chọn vật tư").tag("")
                                        ForEach(activeMaterials) { material in
                                            Text("\(material.name) · tồn \(Formatters.number(material.quantityValue))")
                                                .tag(material.id)
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(AppTheme.primary)
                                    .onChange(of: selectedMaterialId) { _, newValue in
                                        if let material = materials.first(where: { $0.id == newValue }) {
                                            unitPrice = material.importCost ?? material.priceValue
                                        }
                                    }
                                }

                                if let material = selectedMaterial {
                                    HStack {
                                        Text("Tồn hiện tại")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Formatters.number(material.quantityValue)) \(material.unitValue)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                }

                                FormNumberRow(
                                    title: "Số lượng",
                                    value: $quantity,
                                    suffix: selectedMaterial?.unitValue,
                                    width: 88
                                )
                                FormNumberRow(
                                    title: "Giá nhập đợt này",
                                    value: $unitPrice,
                                    suffix: "/\(selectedMaterial?.unitValue ?? "đv")",
                                    width: 100
                                )

                                Text("Giá này được lưu riêng cho phiếu hiện tại và dùng làm giá gợi ý cho lần nhập sau.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Button {
                                    addDraft()
                                } label: {
                                    Label("Thêm vào phiếu nhập", systemImage: "plus.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                }
                                .foregroundStyle(.white)
                                .background(
                                    selectedMaterial != nil && quantity > 0
                                        ? AppTheme.primary
                                        : Color.gray.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                )
                                .disabled(selectedMaterial == nil || quantity <= 0)
                            }
                        }
                    }

                    FormSection(title: "Mặt hàng nhập (\(drafts.count))") {
                        if drafts.isEmpty {
                            Text("Chưa có mặt hàng nào.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach($drafts) { $draft in
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Text(draft.material.name)
                                            .font(.subheadline.weight(.semibold))
                                        if draft.isNewMaterial {
                                            Text("Mới")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(AppTheme.warning)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.warning.opacity(0.12), in: Capsule())
                                        }
                                        Spacer()
                                        Text(Formatters.money(draft.total))
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(AppTheme.success)
                                    }

                                    HStack(spacing: 8) {
                                        Text("SL")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        TextField("0", value: $draft.quantity, format: .number)
                                            .font(.subheadline.weight(.medium))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 60)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 7)
                                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Text(draft.material.unitValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        TextField("Giá", value: $draft.unitPrice, format: .number)
                                            .font(.caption.weight(.medium))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 82)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 7)
                                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Button {
                                            drafts.removeAll { $0.id == draft.id }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(AppTheme.danger)
                                                .frame(width: 32, height: 32)
                                                .background(AppTheme.danger.opacity(0.10), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if draft.id != drafts.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    FormSection(title: "Thanh toán") {
                        FormNumberRow(title: "Giảm giá", value: $discountRate, suffix: "%", width: 66)
                        FormNumberRow(title: "Thuế", value: $taxRate, suffix: "%", width: 66)
                        FormNumberRow(title: "Đã trả NCC", value: $paidAmount, suffix: "đ", width: 108)
                    }

                    FormSection(title: "Tổng cộng") {
                        FormTotalRow(title: "Tạm tính", value: Formatters.money(subtotal))
                        FormTotalRow(title: "Giảm giá", value: "-\(Formatters.money(discountAmount))", color: AppTheme.warning)
                        FormTotalRow(title: "Thuế", value: Formatters.money(taxAmount))
                        Divider()
                        FormTotalRow(title: "Tổng cộng", value: Formatters.money(total), isTotal: true, color: AppTheme.primary)
                        FormTotalRow(title: "Còn nợ", value: Formatters.money(max(0, total - paidAmount)), color: AppTheme.danger)
                    }

                    FormSection(title: "Ghi chú") {
                        FormField(
                            title: "Ghi chú",
                            placeholder: "Ghi chú cho phiếu nhập (không bắt buộc)",
                            icon: "text.alignleft",
                            text: $notes,
                            axis: .vertical,
                            lineLimit: 2...4
                        )
                    }

                    if let error {
                        ErrorBanner(message: error)
                    }
                }
                .padding(AppTheme.screenPadding)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Phiếu nhập hàng")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FormActionBar(
                    isSaving: isSaving,
                    canSave: !drafts.isEmpty,
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .interactiveDismissDisabled(isSaving)
            .task { await loadMaterials() }
        }
        .presentationDetents([.large])
    }

    private func addDraft() {
        guard let material = selectedMaterial, quantity > 0 else { return }
        // Chỉ gộp khi cùng vật tư và cùng đơn giá.
        // Nếu giá nhập khác nhau, giữ thành 2 dòng riêng để không ghi đè giá cũ.
        if let index = drafts.firstIndex(where: {
            $0.material.id == material.id && abs($0.unitPrice - unitPrice) < 0.001
        }) {
            drafts[index].quantity = roundMoney(drafts[index].quantity + quantity)
        } else {
            drafts.append(
                StockInDraftItem(
                    material: material,
                    quantity: quantity,
                    unitPrice: unitPrice
                )
            )
        }
        quantity = 1
    }

    private func addNewMaterialDraft() {
        let trimmedName = newMaterialName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            newMaterialError = "Vui lòng nhập tên vật tư."
            return
        }
        guard quantity > 0 else {
            newMaterialError = "Số lượng nhập phải lớn hơn 0."
            return
        }

        if materials.contains(where: {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            newMaterialError = "Vật tư này đã tồn tại. Chọn ở “Vật tư có sẵn”."
            return
        }

        let existingDraft = drafts.first {
            $0.isNewMaterial
                && $0.material.name.caseInsensitiveCompare(trimmedName) == .orderedSame
                && ($0.material.category ?? "") == newMaterialCategory
                && ($0.material.unit ?? "") == newMaterialUnit
        }

        if existingDraft == nil, drafts.contains(where: {
            $0.isNewMaterial && $0.material.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            newMaterialError = "Tên vật tư đã có trong phiếu với danh mục/đơn vị khác."
            return
        }

        let tempMaterial: Material
        if let existingDraft {
            tempMaterial = existingDraft.material
        } else {
            tempMaterial = Material(
                id: "new-\(UUID().uuidString)",
                name: trimmedName,
                category: newMaterialCategory,
                price: newMaterialPrice,
                importCost: unitPrice,
                quantity: 0,
                unit: newMaterialUnit,
                supplier: supplier,
                description: "",
                minStock: newMaterialMinStock,
                maxStock: 0,
                location: "",
                isActive: true,
                createdAt: nil,
                updatedAt: nil
            )
        }

        if let index = drafts.firstIndex(where: {
            $0.material.id == tempMaterial.id && abs($0.unitPrice - unitPrice) < 0.001
        }) {
            drafts[index].quantity = roundMoney(drafts[index].quantity + quantity)
        } else {
            drafts.append(
                StockInDraftItem(
                    material: tempMaterial,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    isNewMaterial: true
                )
            )
        }

        newMaterialError = nil
        newMaterialName = ""
        newMaterialPrice = 0
        newMaterialMinStock = 10
        quantity = 1
        unitPrice = 0
    }

    private func save() {
        guard let profile = auth.profile else {
            error = "Phiên đăng nhập không hợp lệ."
            return
        }
        guard drafts.allSatisfy({ $0.quantity > 0 }) else {
            error = "Số lượng mỗi mặt hàng phải lớn hơn 0."
            return
        }

        error = nil
        isSaving = true
        Task {
            var createdMaterialIds: [String] = []
            do {
                var resolvedDrafts = drafts
                var createdByTempId: [String: Material] = [:]

                for index in resolvedDrafts.indices where resolvedDrafts[index].isNewMaterial {
                    let temp = resolvedDrafts[index].material
                    if let existing = createdByTempId[temp.id] {
                        resolvedDrafts[index].material = existing
                        resolvedDrafts[index].isNewMaterial = false
                        continue
                    }

                    let createdMaterial = try await materialService.createMaterial(
                        name: temp.name,
                        category: temp.category ?? MaterialOptions.categories[0],
                        unit: temp.unit ?? "cái",
                        quantity: 0,
                        price: temp.priceValue,
                        importCost: resolvedDrafts[index].unitPrice,
                        supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: temp.description ?? "",
                        minStock: temp.minStockValue,
                        maxStock: temp.maxStock ?? 0,
                        location: temp.location ?? "",
                        isActive: true,
                        profile: profile
                    )
                    createdMaterialIds.append(createdMaterial.id)
                    createdByTempId[temp.id] = createdMaterial
                    resolvedDrafts[index].material = createdMaterial
                    resolvedDrafts[index].isNewMaterial = false
                }

                let created = try await service.createStockIn(
                    supplier: supplier,
                    supplierPhone: supplierPhone,
                    supplierAddress: supplierAddress,
                    drafts: resolvedDrafts,
                    taxRate: taxRate,
                    discountRate: discountRate,
                    paidAmount: max(0, min(paidAmount, total)),
                    notes: notes,
                    profile: profile
                )
                NotificationCenter.default.post(name: .materialsDidChange, object: nil)
                onCreated(created)
                dismiss()
            } catch {
                // Nếu lưu phiếu thất bại, xoá các vật tư vừa tạo để không rác dữ liệu.
                for id in createdMaterialIds {
                    try? await materialService.deleteMaterial(id: id)
                }
                if !error.isCancellation {
                    self.error = error.userFacingMessage
                }
            }
            isSaving = false
        }
    }

    @MainActor
    private func loadMaterials() async {
        isLoading = true
        do {
            materials = try await materialService.fetchMaterials()
        } catch {
            if !error.isCancellation {
                self.error = error.userFacingMessage
            }
        }
        isLoading = false
    }
}
