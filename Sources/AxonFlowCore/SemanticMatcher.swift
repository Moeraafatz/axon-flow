import Foundation

/// Resolves semantic `AXSelector` queries against any macOS Accessibility snapshot tree.
/// Completely invariant to window moves, display scaling, and pixel layout shifts.
public enum SemanticMatcher {
    public static func resolve(selector: AXSelector, in nodes: [AXSnapshotNode]) -> SelectorMatchResult? {
        let start = CFAbsoluteTimeGetCurrent()
        var bestNode: AXSnapshotNode?
        var bestScore: Double = 0
        var bestStrategy: SelectorStrategy = .fallback

        let targetID = selector.identifier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetTitle = selector.title?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetHelp = selector.helpText?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for node in nodes where node.isEnabled {
            var score = 0.0
            var strategy: SelectorStrategy = .fallback

            // 1. Role & Subrole gate
            if node.role == selector.role {
                score += 22.0
            } else {
                // Wrong role is heavily penalized unless identifier matches exactly
                score -= 10.0
            }

            if let sr = selector.subrole, !sr.isEmpty, node.subrole == sr {
                score += 8.0
            }

            // 2. Strongest signal: AXIdentifier exact match
            if let targetID, !targetID.isEmpty, let nodeID = node.identifier?.lowercased(), !nodeID.isEmpty {
                if nodeID == targetID {
                    score += 65.0
                    strategy = .identifier
                } else if nodeID.contains(targetID) || targetID.contains(nodeID) {
                    score += 28.0
                }
            }

            // 3. Semantic Title / Description match (exact or token overlap for dynamic badges like "Inbox (14)")
            if let targetTitle, !targetTitle.isEmpty, let nodeTitle = node.title?.lowercased(), !nodeTitle.isEmpty {
                if nodeTitle == targetTitle {
                    score += 36.0
                    if strategy != .identifier { strategy = .titleAndRole }
                } else if nodeTitle.hasPrefix(targetTitle) || targetTitle.hasPrefix(nodeTitle) {
                    score += 26.0
                    if strategy != .identifier { strategy = .titleAndRole }
                } else {
                    let overlap = tokenOverlapRatio(targetTitle, nodeTitle)
                    if overlap >= 0.5 {
                        score += 22.0 * overlap
                        if strategy != .identifier { strategy = .ancestorFuzzy }
                    }
                }
            }

            // 4. Help / Accessibility Description secondary anchor
            if let targetHelp, !targetHelp.isEmpty, let nodeHelp = node.helpText?.lowercased(), nodeHelp == targetHelp {
                score += 14.0
            }

            // 5. Ancestor role chain suffix match (e.g. ["AXWindow", "AXSplitGroup", "AXToolbar"])
            if !selector.ancestorRoles.isEmpty && !node.ancestorRoles.isEmpty {
                let suffixMatch = commonSuffixLength(selector.ancestorRoles, node.ancestorRoles)
                let ratio = Double(suffixMatch) / Double(selector.ancestorRoles.count)
                score += 16.0 * ratio
                if ratio >= 0.75 && strategy == .fallback && node.role == selector.role {
                    strategy = .ancestorFuzzy
                }
            }

            // 6. Sibling index tie-breaker
            if node.siblingIndex == selector.siblingIndex {
                score += 4.5
            }

            if score > bestScore {
                bestScore = score
                bestNode = node
                bestStrategy = strategy
            }
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        guard let winner = bestNode, bestScore >= 32.0 else { return nil }
        return SelectorMatchResult(
            node: winner,
            score: min(100.0, bestScore),
            strategy: bestStrategy,
            durationMs: elapsed
        )
    }

    /// Evaluates whether a brittle pixel-coordinate click at `selector.recordedScreenPoint` still hits the true node.
    public static func pixelClickHitsTarget(selector: AXSelector, trueTargetNode: AXSnapshotNode) -> Bool {
        trueTargetNode.frame.contains(x: selector.recordedScreenPoint.x, y: selector.recordedScreenPoint.y)
    }

    private static func commonSuffixLength(_ a: [String], _ b: [String]) -> Int {
        var i = a.count - 1
        var j = b.count - 1
        var count = 0
        while i >= 0 && j >= 0 && a[i] == b[j] {
            count += 1
            i -= 1
            j -= 1
        }
        return count
    }

    private static func tokenOverlapRatio(_ a: String, _ b: String) -> Double {
        let ta = Set(a.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        let tb = Set(b.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        guard !ta.isEmpty && !tb.isEmpty else { return 0 }
        let inter = ta.intersection(tb).count
        return Double(inter) / Double(min(ta.count, tb.count))
    }
}
