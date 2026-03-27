import SwiftUI

struct HistorySectionView: View {
    let history: [HistoryItem]
    @Binding var isHistoryExpanded: Bool
    @Binding var selectedHistory: UUID?
    @Binding var hoveredHistory: UUID?
    @Binding var historyHasOverflow: Bool
    @Binding var hasUserScrolled: Bool
    let glassTint: Color
    let observedSystemScheme: ColorScheme
    let localizedText: (String, String) -> String
    let modeLabel: (String) -> String
    let emotionLabel: (Emotion) -> String
    let roleLabel: (Role) -> String
    let onApply: (HistoryItem) -> Void
    let onDelete: (HistoryItem) -> Void
    let onCopy: () -> Void

    private var canScrollHistory: Bool {
        historyHasOverflow
    }

    private var shouldDisplayHistoryHint: Bool {
        canScrollHistory && !hasUserScrolled
    }

    var body: some View {
        Group {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        isHistoryExpanded.toggle()
                    } label: {
                        VStack(alignment: .leading, spacing: isHistoryExpanded ? 0 : 6) {
                            HStack(alignment: .center, spacing: 12) {
                                HStack(spacing: 6) {
                                    Text(localizedText("Historial", "History"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text("\(history.count)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                historyToggleChip
                            }

                            if !isHistoryExpanded {
                                Text(localizedText("Toca para ver los ajustes guardados", "Click to view saved presets"))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                        .padding(.bottom, isHistoryExpanded ? 0 : 2)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .frame(minHeight: isHistoryExpanded ? 36 : 58, alignment: .top)
                    .padding(.bottom, isHistoryExpanded ? 0 : 10)

                    if isHistoryExpanded {
                        ScrollView {
                            VStack(spacing: 6) {
                                ScrollInteractionObserver {
                                    hasUserScrolled = true
                                } onOverflowChange: { hasOverflow in
                                    historyHasOverflow = hasOverflow
                                }
                                .frame(width: 0, height: 0)

                                ForEach(history, id: \.id) { item in
                                    historyRow(item)
                                        .transition(.opacity)
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: history)
                            .padding(.top, 2)
                        }
                        .onAppear {
                            historyHasOverflow = false
                        }
                        .onChange(of: isHistoryExpanded) { _ in
                            hasUserScrolled = false
                            historyHasOverflow = false
                        }
                        .onChange(of: history.count) { _ in
                            hasUserScrolled = false
                            historyHasOverflow = false
                        }
                        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.14), value: isHistoryExpanded)
                        .overlay(alignment: .bottom) {
                            if shouldDisplayHistoryHint {
                                VStack(spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.down")
                                        Text(localizedText("Desliza para ver más", "Scroll to see more"))
                                        Image(systemName: "chevron.down")
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.92))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.blue.opacity(observedSystemScheme == .dark ? 0.7 : 0.62),
                                                        Color.blue.opacity(observedSystemScheme == .dark ? 0.5 : 0.44)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(observedSystemScheme == .dark ? 0.12 : 0.18))
                                    )
                                    .shadow(
                                        color: Color.blue.opacity(observedSystemScheme == .dark ? 0.22 : 0.14),
                                        radius: 8,
                                        y: 1
                                    )
                                    .padding(.bottom, 6)
                                }
                                .allowsHitTesting(false)
                                .transition(.opacity)
                            }
                        }
                    }
                }
                .padding(.bottom, isHistoryExpanded ? 0 : 4)
            }
        }
    }

    private var historyToggleChip: some View {
        ZStack {
            historyToggleLabel(title: localizedText("Mostrar", "Show"), symbol: "chevron.down.circle.fill")
                .opacity(isHistoryExpanded ? 0 : 1)

            historyToggleLabel(title: localizedText("Ocultar", "Hide"), symbol: "chevron.up.circle.fill")
                .opacity(isHistoryExpanded ? 1 : 0)
        }
        .frame(width: 86)
        .transaction { transaction in
            transaction.animation = nil
        }
        .foregroundStyle(isHistoryExpanded ? .secondary : .primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(isHistoryExpanded ? 0.04 : 0.08)))
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        historyRowContent(item)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 44)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onApply(item)
                    selectedHistory = item.id
                }
                onCopy()
            }
            .overlay(alignment: .trailing) {
                Button {
                    onDelete(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hoveredHistory == item.id ? Color.red : Color.secondary)
                        .frame(width: 36, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 6)
                .opacity(hoveredHistory == item.id ? 1 : 0.35)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedHistory == item.id
                ? Color.blue.opacity(0.25)
                : (hoveredHistory == item.id ? Color.primary.opacity(0.10) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        selectedHistory == item.id
                        ? Color.blue.opacity(0.4)
                        : glassTint.opacity(0.9)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .zIndex(1)
            .onHover { hovering in
                hoveredHistory = hovering ? item.id : nil
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedHistory)
            .contextMenu {
                Button(localizedText("Copiar ajustes", "Copy preset")) {
                    onApply(item)
                    onCopy()
                }
                Button(localizedText("Eliminar", "Delete")) {
                    onDelete(item)
                }
            }
    }

    private func historyToggleLabel(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))

            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
        }
    }

    private func historyRowContent(_ item: HistoryItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 6) {
                let label = item.multiplier == 2.0 ? "×2" : "÷2"

                Group {
                    if item.multiplier != 1.0 {
                        if #available(macOS 26.0, *) {
                            Text(label)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.blue,
                                            Color.cyan.opacity(0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.blue.opacity(0.35), radius: 2, y: 0)
                        } else {
                            Text(label)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.85))
                                )
                        }
                    } else {
                        Text(label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .opacity(0)
                    }
                }
                .frame(width: 28)

                Text("\(Int(item.bpm))")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(modeLabel(item.mode)) · \(emotionLabel(item.emotion)) · \(roleLabel(item.role))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                let resultBPM = Int(item.bpm * item.multiplier)
                Text(
                    item.multiplier != 1.0
                    ? "→ \(resultBPM) BPM"
                    : " "
                )
                .font(.caption2)
                .opacity(item.multiplier != 1.0 ? 1 : 0)
                .frame(height: 12)

                HStack(spacing: 6) {
                    Text("Pre \(item.preDelay) ms")
                    Text("·")
                    Text(String(format: "%.2f s", Double(item.decay) / 1000))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .scaleEffect(selectedHistory == item.id ? 1.02 : 1)
        .blur(radius: hoveredHistory == item.id ? 0.2 : 0)
    }
}
