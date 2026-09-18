import SwiftUI

struct ChecklistList: View {
    var items: [ChecklistItem]
    var addPrompt: String = "Add a task"
    var itemListMaxHeight: CGFloat = 160
    var itemListHeight: CGFloat? = nil
    var onAdd: (String) -> Void
    var onToggle: (UUID) -> Void
    var onDelete: (UUID) -> Void

    @State private var draft = ""
    @State private var hoveredID: UUID?
    @FocusState private var addFocused: Bool

    private var openItems: [ChecklistItem] { items.filter { !$0.isChecked } }
    private var doneItems: [ChecklistItem] { items.filter(\.isChecked) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            composer
            itemList
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(maxHeight: itemListHeight == nil ? nil : .infinity, alignment: .top)
    }

    private var listViewportHeight: CGFloat {
        itemListHeight ?? itemListMaxHeight
    }

    private var itemList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                if items.isEmpty {
                    Text("No tasks")
                        .font(Theme.Typeface.caption())
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                } else {
                    ForEach(openItems) { item in
                        row(item)
                            .transition(.opacity)
                    }
                    if !doneItems.isEmpty {
                        if !openItems.isEmpty {
                            Text("Done")
                                .font(Theme.Typeface.micro())
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 8)
                                .padding(.bottom, 2)
                                .padding(.horizontal, 8)
                                .transition(.opacity)
                        }
                        ForEach(doneItems) { item in
                            row(item)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Theme.Motion.fadeAnimation, value: items.map(\.id))
            .padding(.bottom, 8)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: listViewportHeight)
        .contentShape(Rectangle())
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(addFocused || !draft.isEmpty ? Theme.pink : Theme.muted)
            TextField(addPrompt, text: $draft)
                .textFieldStyle(.plain)
                .font(Theme.Typeface.body())
                .foregroundStyle(Theme.text)
                .focused($addFocused)
                .onSubmit(submitDraft)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: Theme.fieldHeight, alignment: .leading)
        .background(Theme.fill)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                .strokeBorder(addFocused ? Theme.pink : Color.clear, lineWidth: 1)
        }
        .animation(Theme.Motion.colorAnimation, value: addFocused)
    }

    private func row(_ item: ChecklistItem) -> some View {
        let hovering = hoveredID == item.id
        return HStack(spacing: 8) {
            Button {
                onToggle(item.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(item.isChecked || hovering ? Theme.pink : Theme.muted)
                        .frame(width: 16)
                    Text(item.text)
                        .font(Theme.Typeface.body())
                        .foregroundStyle(item.isChecked ? Theme.muted : Theme.text)
                        .strikethrough(item.isChecked, color: Theme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onDelete(item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IconHoverButtonStyle(idle: Theme.muted))
            .help("Remove")
            .opacity(hovering ? 1 : 0)
            .animation(Theme.Motion.colorAnimation, value: hovering)
            .allowsHitTesting(hovering)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(hovering ? Theme.fill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .animation(Theme.Motion.colorAnimation, value: hovering)
        .onHover { isHovering in
            hoveredID = isHovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
        }
    }

    private func submitDraft() {
        let text = draft
        draft = ""
        addFocused = true
        onAdd(text)
    }
}
