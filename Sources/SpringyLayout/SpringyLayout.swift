import UIKit

open class BouncyLayout: UICollectionViewFlowLayout {
    lazy var dynamicAnimator = UIDynamicAnimator(collectionViewLayout: self)
    var latestDelta: CGFloat = 0.0
    var visibleIndexPaths: Set<IndexPath> = []

    override init() {
        super.init()

        minimumInteritemSpacing = 10.0
        minimumLineSpacing = 10.0
        itemSize = CGSize(width: 44.0, height: 44.0)
        sectionInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0) // TODO: make open prop
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func prepare() {
        super.prepare()

        // Need to overflow our actual visible rect slightly to avoid flickering.
        guard let collectionView = collectionView else { return }

        let rect = CGRect(origin: collectionView.bounds.origin, size: collectionView.frame.size)
        let visibleRect = rect.insetBy(dx: -100.0, dy: -100.0)
        guard let itemsInVisibleRect = super.layoutAttributesForElements(in: visibleRect) else { return }
        let itemsIndexPathsInVisibleRect: Set<IndexPath> = Set(itemsInVisibleRect.map { $0.indexPath })

        // Step 1: Remove any behaviours that are no longer visible.
        let noLongerVisibleBehaviors = dynamicAnimator.behaviors.filter { behavior in
            guard
                let behaviorItem = (behavior as? UIAttachmentBehavior)?.items.first,
                let layoutAttribute = behaviorItem as? UICollectionViewLayoutAttributes
            else { return false }

            return !itemsIndexPathsInVisibleRect.contains(layoutAttribute.indexPath)
        }

        noLongerVisibleBehaviors.forEach { behavior in
            dynamicAnimator.removeBehavior(behavior)
            if let layoutAttribute = (behavior as? UIAttachmentBehavior)?.items.first as? UICollectionViewLayoutAttributes {
                visibleIndexPaths.remove(layoutAttribute.indexPath)
            }
        }

        // Step 2: Add any newly visible behaviours.
        // A "newly visible" item is one that is in the itemsInVisibleRect(Set|Array) but not in the visibleIndexPathsSet
        let newlyVisibleItems = itemsInVisibleRect.filter { !visibleIndexPaths.contains($0.indexPath) }
        let touchLocation = collectionView.panGestureRecognizer.location(in: collectionView)

        newlyVisibleItems.forEach { item in
            var center = item.center
            let springBehavior = UIAttachmentBehavior(item: item, attachedToAnchor: center)

            springBehavior.length = 0.0
            springBehavior.damping = 0.8
            springBehavior.length = 1.0

            // If our touchLocation is not (0,0), we'll need to adjust our item's center "in flight"
            if CGPoint.zero != touchLocation {
                let yDistanceFromTouch = abs(touchLocation.y - springBehavior.anchorPoint.y)
                let xDistanceFromTouch = abs(touchLocation.x - springBehavior.anchorPoint.x)
                let scrollResistance = (yDistanceFromTouch + xDistanceFromTouch) / 1_500.0

                if latestDelta < 0 {
                    center.y += max(latestDelta, latestDelta * scrollResistance)
                } else {
                    center.y += min(latestDelta, latestDelta * scrollResistance)
                }
                item.center = center
            }

            dynamicAnimator.addBehavior(springBehavior)
            visibleIndexPaths.insert(item.indexPath)
        }
    }

    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return dynamicAnimator.items(in: rect) as? [UICollectionViewLayoutAttributes]
    }

    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return dynamicAnimator.layoutAttributesForCell(at: indexPath)
    }

    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        let scrollView = collectionView

        let delta = newBounds.origin.y - scrollView.bounds.origin.y
        latestDelta = delta

        let touchLocation = collectionView.panGestureRecognizer.location(in: collectionView)

        dynamicAnimator.behaviors.forEach { behavior in
            guard let springBehavior = behavior as? UIAttachmentBehavior else { return }
            let yDistanceFromTouch = abs(touchLocation.y - springBehavior.anchorPoint.y)
            let xDistanceFromTouch = abs(touchLocation.x - springBehavior.anchorPoint.x)

            let scrollResistance = (yDistanceFromTouch + xDistanceFromTouch) / 1_500.0

            if let item = springBehavior.items.first as? UICollectionViewLayoutAttributes {
                var center = item.center
                if delta < 0 {
                    center.y += max(delta, delta * scrollResistance)
                } else {
                    center.y += min(delta, delta * scrollResistance)
                }
                item.center = center

                dynamicAnimator.updateItem(usingCurrentState: item)
            }
        }

        return false
    }

}
