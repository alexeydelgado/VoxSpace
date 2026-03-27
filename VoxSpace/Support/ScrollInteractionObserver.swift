import AppKit
import SwiftUI

struct ScrollInteractionObserver: NSViewRepresentable {
    let onUserScroll: () -> Void
    let onOverflowChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onUserScroll: onUserScroll, onOverflowChange: onOverflowChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = TrackingNSView()
        view.onAttach = { [weak coordinator = context.coordinator, weak view] in
            guard let coordinator, let view else { return }
            coordinator.attach(to: view)
        }
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onUserScroll = onUserScroll
        context.coordinator.onOverflowChange = onOverflowChange
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class TrackingNSView: NSView {
        var onAttach: (() -> Void)?

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            onAttach?()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onAttach?()
        }
    }

    final class Coordinator {
        var onUserScroll: () -> Void
        var onOverflowChange: (Bool) -> Void
        private weak var observedScrollView: NSScrollView?
        private weak var observedView: NSView?
        private var localMonitor: Any?
        private var boundsObserver: NSObjectProtocol?
        private var frameObserver: NSObjectProtocol?

        init(onUserScroll: @escaping () -> Void, onOverflowChange: @escaping (Bool) -> Void) {
            self.onUserScroll = onUserScroll
            self.onOverflowChange = onOverflowChange
        }

        func attach(to view: NSView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                let scrollView = view.enclosingScrollView
                    ?? sequence(first: view.superview, next: { $0?.superview })
                        .compactMap { $0 as? NSScrollView }
                        .first

                guard observedScrollView !== scrollView else { return }

                detach()
                observedScrollView = scrollView
                observedView = view

                guard scrollView != nil else { return }
                let clipView = scrollView!.contentView
                clipView.postsBoundsChangedNotifications = true
                scrollView!.documentView?.postsFrameChangedNotifications = true

                boundsObserver = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: clipView,
                    queue: .main
                ) { [weak self] _ in
                    self?.reportOverflow()
                }

                frameObserver = NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: scrollView!.documentView,
                    queue: .main
                ) { [weak self] _ in
                    self?.reportOverflow()
                }

                reportOverflow()

                localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    guard let self else { return event }
                    guard
                        let observedView = self.observedView,
                        let observedScrollView = self.observedScrollView,
                        let window = observedView.window,
                        event.window === window
                    else {
                        return event
                    }

                    let locationInWindow = event.locationInWindow
                    let locationInScrollView = observedScrollView.convert(locationInWindow, from: nil)
                    guard observedScrollView.bounds.contains(locationInScrollView) else {
                        return event
                    }

                    self.onUserScroll()
                    return event
                }
            }
        }

        private func reportOverflow() {
            guard let scrollView = observedScrollView else { return }
            let documentHeight = scrollView.documentView?.frame.height ?? 0
            let viewportHeight = scrollView.contentView.bounds.height
            onOverflowChange(documentHeight > viewportHeight)
        }

        func detach() {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
                self.boundsObserver = nil
            }
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
                self.frameObserver = nil
            }
            observedView = nil
            observedScrollView = nil
        }

        deinit {
            detach()
        }
    }
}
