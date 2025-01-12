import Foundation
import UIKit

private func findTaggedViewImpl(view: UIView, tag: Any) -> UIView? {
    if let view = view as? ComponentTaggedView {
        if view.matches(tag: tag) {
            return view
        }
    }
    
    for subview in view.subviews {
        if let result = findTaggedViewImpl(view: subview, tag: tag) {
            return result
        }
    }
    
    return nil
}

public final class ComponentHostView<EnvironmentType: Equatable>: UIView {
    private var currentComponent: AnyComponent<EnvironmentType>?
    private var currentContainerSize: CGSize?
    private var currentSize: CGSize?
    private var componentView: UIView?
    private(set) var isUpdating: Bool = false
    
    public init() {
        super.init(frame: CGRect())
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(transition: Transition, component: AnyComponent<EnvironmentType>, @EnvironmentBuilder environment: () -> Environment<EnvironmentType>, containerSize: CGSize) -> CGSize {
        let size = self._update(transition: transition, component: component, maybeEnvironment: environment, updateEnvironment: true, forceUpdate: false, containerSize: containerSize)
        self.currentSize = size
        return size
    }

    private func _update(transition: Transition, component: AnyComponent<EnvironmentType>, maybeEnvironment: () -> Environment<EnvironmentType>, updateEnvironment: Bool, forceUpdate: Bool, containerSize: CGSize) -> CGSize {
        precondition(!self.isUpdating)
        self.isUpdating = true

        precondition(containerSize.width.isFinite)
        precondition(containerSize.width < .greatestFiniteMagnitude)
        precondition(containerSize.height.isFinite)
        precondition(containerSize.height < .greatestFiniteMagnitude)
        
        let componentView: UIView
        if let current = self.componentView {
            componentView = current
        } else {
            componentView = component._makeView()
            self.componentView = componentView
            self.addSubview(componentView)
        }

        let context = componentView.context(component: component)

        let componentState: ComponentState = context.erasedState

        if updateEnvironment {
            EnvironmentBuilder._environment = context.erasedEnvironment
            let _ = maybeEnvironment()
            EnvironmentBuilder._environment = nil
        }
        
        let isEnvironmentUpdated = context.erasedEnvironment.calculateIsUpdated()
        if isEnvironmentUpdated {
            context.erasedEnvironment._isUpdated = false
        }
        
        if !forceUpdate, !isEnvironmentUpdated, let currentComponent = self.currentComponent, let currentContainerSize = self.currentContainerSize, let currentSize = self.currentSize {
            if currentContainerSize == containerSize && currentComponent == component {
                self.isUpdating = false
                return currentSize
            }
        }
        self.currentComponent = component
        self.currentContainerSize = containerSize

        componentState._updated = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf._update(transition: transition, component: component, maybeEnvironment: {
                preconditionFailure()
            } as () -> Environment<EnvironmentType>, updateEnvironment: false, forceUpdate: true, containerSize: containerSize)
        }

        let updatedSize = component._update(view: componentView, availableSize: containerSize, environment: context.erasedEnvironment, transition: transition)
        transition.setFrame(view: componentView, frame: CGRect(origin: CGPoint(), size: updatedSize))

        self.isUpdating = false

        return updatedSize
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result
    }
    
    public func findTaggedView(tag: Any) -> UIView? {
        guard let componentView = self.componentView else {
            return nil
        }
        
        return findTaggedViewImpl(view: componentView, tag: tag)
    }
}
