import Foundation
import SwiftUI

// MARK: - Public output types

struct PositionedPerson: Identifiable {
    let id: UUID          // same as person.id
    let person: Person
    var position: CGPoint
}

struct TreeEdge: Identifiable {
    enum Kind { case parentChild, spouseLink }
    let id = UUID()
    let from: CGPoint
    let to: CGPoint
    let kind: Kind
}

struct TreeLayout {
    let people: [PositionedPerson]
    let edges: [TreeEdge]
    let size: CGSize
    let unlinked: [Person]   // not reachable from "Me" via any link

    static let empty = TreeLayout(
        people: [], edges: [],
        size: CGSize(width: 400, height: 300),
        unlinked: []
    )
}

// MARK: - Internal layout unit

private struct FamilyUnit {
    let primary: Person
    let spouse: Person?
    let gen: Int
    var xCenter: CGFloat = 0

    // Width of this unit in canvas points
    var width: CGFloat {
        spouse != nil
            ? TreeLayoutEngine.nodeW * 2 + TreeLayoutEngine.spouseGap
            : TreeLayoutEngine.nodeW
    }
}

// MARK: - Engine

final class TreeLayoutEngine {

    // Layout constants (accessible from FamilyUnit)
    static let nodeW:     CGFloat = 70
    static let nodeH:     CGFloat = 88
    static let spouseGap: CGFloat = 10   // horizontal gap between paired nodes
    static let unitGap:   CGFloat = 28   // gap between separate family units
    static let rowHeight: CGFloat = 160  // vertical distance between generations
    static let padding:   CGFloat = 50   // canvas edge padding

    private let people: [Person]
    private let byID:   [UUID: Person]

    init(people: [Person]) {
        self.people = people
        self.byID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
    }

    // MARK: - Main entry point

    func buildLayout() -> TreeLayout {
        guard !people.isEmpty else { return TreeLayout.empty }

        // Anchor: "Me" if set, otherwise first person
        let anchor = people.first(where: { $0.isMe }) ?? people.first!

        // 1. Find all connected components via repeated BFS.
        //    Anchor's component comes first; additional clusters are stacked below.
        var visited      = Set<UUID>()
        var mergedGenMap = [UUID: Int]()
        var nextOffset   = 0                  // generation row offset for each cluster
        var pendingStarts: [Person] = [anchor]

        while let start = pendingStarts.first {
            pendingStarts.removeFirst()
            guard !visited.contains(start.id) else { continue }

            let relMap = assignGenerations(from: start)
            guard !relMap.isEmpty else { continue }

            // Shift this cluster so its top row sits at nextOffset
            let minG  = relMap.values.min()!
            let maxG  = relMap.values.max()!
            let shift = nextOffset - minG
            for (id, gen) in relMap { mergedGenMap[id] = gen + shift }
            visited.formUnion(relMap.keys)

            // Leave a 2-row gap before the next cluster
            nextOffset += (maxG - minG) + 2

            // Queue the next unvisited person who has at least one relationship
            if let next = people.first(where: {
                !visited.contains($0.id) && hasAnyLink($0)
            }) {
                pendingStarts.append(next)
            }
        }

        // Only people with zero relationships of any kind go to the unlinked strip
        let unlinked = people.filter { !visited.contains($0.id) }

        guard !mergedGenMap.isEmpty else { return TreeLayout.empty }

        // 2. Group people into family units (person + optional spouse) per generation
        var unitsByGen = groupIntoUnits(genMap: mergedGenMap)

        // 3. Top-down x-position assignment (sort each row by parent position)
        unitsByGen = assignXPositions(unitsByGen: unitsByGen)

        // 4. Compute canvas bounding box
        let minGen = unitsByGen.keys.min()!
        let maxGen = unitsByGen.keys.max()!
        let numRows = maxGen - minGen + 1

        var allXEdges: [CGFloat] = [0]
        for (_, units) in unitsByGen {
            for u in units {
                allXEdges.append(u.xCenter - u.width / 2)
                allXEdges.append(u.xCenter + u.width / 2)
            }
        }
        let minX     = (allXEdges.min()!) - Self.padding
        let maxX     = (allXEdges.max()!) + Self.padding
        let canvasW  = max(maxX - minX, 320)
        let canvasH  = CGFloat(numRows) * Self.rowHeight + Self.padding * 2

        // 5. Convert units → PositionedPerson array + position map
        var positioned = [PositionedPerson]()
        var posMap     = [UUID: CGPoint]()

        for (gen, units) in unitsByGen {
            let rowIdx = gen - minGen
            let y = Self.padding + CGFloat(rowIdx) * Self.rowHeight + Self.nodeH / 2

            for u in units {
                let cx = u.xCenter - minX   // shift so minX → 0

                if let sp = u.spouse {
                    // Couple: primary on left, spouse on right
                    let p1x = cx - Self.nodeW / 2 - Self.spouseGap / 2
                    let p2x = cx + Self.nodeW / 2 + Self.spouseGap / 2
                    let p1  = CGPoint(x: p1x, y: y)
                    let p2  = CGPoint(x: p2x, y: y)
                    positioned.append(PositionedPerson(id: u.primary.id, person: u.primary, position: p1))
                    positioned.append(PositionedPerson(id: sp.id,        person: sp,        position: p2))
                    posMap[u.primary.id] = p1
                    posMap[sp.id]        = p2
                } else {
                    let p = CGPoint(x: cx, y: y)
                    positioned.append(PositionedPerson(id: u.primary.id, person: u.primary, position: p))
                    posMap[u.primary.id] = p
                }
            }
        }

        // 6. Build edges
        var edges = [TreeEdge]()

        // Spouse link edges (short horizontal line between the pair)
        for (_, units) in unitsByGen {
            for u in units {
                guard let sp = u.spouse,
                      let p1 = posMap[u.primary.id],
                      let p2 = posMap[sp.id] else { continue }
                edges.append(TreeEdge(
                    from: CGPoint(x: p1.x + Self.nodeW / 2, y: p1.y),
                    to:   CGPoint(x: p2.x - Self.nodeW / 2, y: p2.y),
                    kind: .spouseLink
                ))
            }
        }

        // Parent-child edges
        for person in people {
            guard let childPos = posMap[person.id] else { continue }
            let childTop = CGPoint(x: childPos.x, y: childPos.y - Self.nodeH / 2 - 4)

            let par1: Person? = person.parent1ID.flatMap { byID[$0] }
            let par2: Person? = person.parent2ID.flatMap { byID[$0] }

            // Check whether both parents are in the same couple unit (spouses of each other)
            let parentsAreCoupled: Bool = {
                guard let p1 = par1, let p2 = par2 else { return false }
                return p1.spouseID == p2.id || p2.spouseID == p1.id
            }()

            if parentsAreCoupled, let p1 = par1, let p2 = par2,
               let pos1 = posMap[p1.id], let pos2 = posMap[p2.id] {
                // Both parents are a couple — single edge from their midpoint
                let fromX = (pos1.x + pos2.x) / 2
                let fromY = max(pos1.y, pos2.y) + Self.nodeH / 2 + 4
                edges.append(TreeEdge(
                    from: CGPoint(x: fromX, y: fromY),
                    to:   childTop,
                    kind: .parentChild
                ))
            } else {
                // Parents are separate units (or only one parent) — draw individual edges
                if let p1 = par1, let pos1 = posMap[p1.id] {
                    // If p1 is in a couple, draw from unit midpoint only when this child
                    // is also a child of that spouse — otherwise draw from p1 directly.
                    let fromX = edgeSourceX(from: p1, posMap: posMap)
                    edges.append(TreeEdge(
                        from: CGPoint(x: fromX, y: pos1.y + Self.nodeH / 2 + 4),
                        to:   childTop,
                        kind: .parentChild
                    ))
                }
                if let p2 = par2, let pos2 = posMap[p2.id] {
                    let fromX = edgeSourceX(from: p2, posMap: posMap)
                    edges.append(TreeEdge(
                        from: CGPoint(x: fromX, y: pos2.y + Self.nodeH / 2 + 4),
                        to:   childTop,
                        kind: .parentChild
                    ))
                }
            }
        }

        return TreeLayout(
            people:   positioned,
            edges:    edges,
            size:     CGSize(width: canvasW, height: canvasH),
            unlinked: unlinked
        )
    }

    // MARK: - Link detection

    /// True if this person has any relationship that would place them in the tree.
    private func hasAnyLink(_ person: Person) -> Bool {
        if person.spouseID  != nil { return true }
        if person.parent1ID != nil { return true }
        if person.parent2ID != nil { return true }
        // Has at least one child in the list
        return people.contains { $0.parent1ID == person.id || $0.parent2ID == person.id }
    }

    // MARK: - Generation assignment (BFS)

    private func assignGenerations(from startPerson: Person) -> [UUID: Int] {
        var map     = [UUID: Int]()
        var visited = Set<UUID>()
        var queue:  [(Person, Int)] = [(startPerson, 0)]

        while !queue.isEmpty {
            let (person, gen) = queue.removeFirst()
            guard !visited.contains(person.id) else { continue }
            visited.insert(person.id)
            map[person.id] = gen

            // Spouse → same generation
            if let sid = person.spouseID, let sp = byID[sid] {
                queue.append((sp, gen))
            }
            // Parent 1 → one generation above
            if let pid = person.parent1ID, let par = byID[pid] {
                queue.append((par, gen - 1))
            }
            // Parent 2 → one generation above
            if let pid = person.parent2ID, let par = byID[pid] {
                queue.append((par, gen - 1))
            }
            // Children → one generation below
            for child in children(of: person) {
                queue.append((child, gen + 1))
            }
            // Siblings (share at least one parent) → same generation
            let myParents = Set([person.parent1ID, person.parent2ID].compactMap { $0 })
            if !myParents.isEmpty {
                let siblings = people.filter { sib in
                    guard sib.id != person.id, !visited.contains(sib.id) else { return false }
                    let sibParents = Set([sib.parent1ID, sib.parent2ID].compactMap { $0 })
                    return !myParents.isDisjoint(with: sibParents)
                }
                for sib in siblings { queue.append((sib, gen)) }
            }
        }
        return map
    }

    /// All children whose parent1ID or parent2ID points to this person
    private func children(of person: Person) -> [Person] {
        people.filter {
            $0.parent1ID == person.id || $0.parent2ID == person.id
        }
    }

    // MARK: - Family unit grouping

    private func groupIntoUnits(genMap: [UUID: Int]) -> [Int: [FamilyUnit]] {
        var result    = [Int: [FamilyUnit]]()
        var processed = Set<UUID>()

        // Sort oldest → youngest so siblings appear left-to-right by age
        let sorted = people.sorted { $0.birthday < $1.birthday }

        for person in sorted {
            guard let gen = genMap[person.id],
                  !processed.contains(person.id) else { continue }

            // Try to pair with spouse if they're in the same generation
            if let sid    = person.spouseID,
               let spouse = byID[sid],
               let spGen  = genMap[sid],
               spGen == gen,
               !processed.contains(sid) {
                // Decide which is primary (the one who has parents links in the tree)
                let personHasParent = person.parent1ID != nil || person.parent2ID != nil
                let spouseHasParent = spouse.parent1ID != nil || spouse.parent2ID != nil
                let primaryFirst = personHasParent || !spouseHasParent
                let unit = primaryFirst
                    ? FamilyUnit(primary: person, spouse: spouse, gen: gen)
                    : FamilyUnit(primary: spouse,  spouse: person,  gen: gen)
                result[gen, default: []].append(unit)
                processed.insert(person.id)
                processed.insert(sid)
            } else {
                result[gen, default: []].append(FamilyUnit(primary: person, spouse: nil, gen: gen))
                processed.insert(person.id)
            }
        }
        return result
    }

    // MARK: - X-position assignment (top-down)

    private func assignXPositions(unitsByGen: [Int: [FamilyUnit]]) -> [Int: [FamilyUnit]] {
        var result    = [Int: [FamilyUnit]]()
        var centerMap = [UUID: CGFloat]()   // personID → their unit's xCenter

        for gen in unitsByGen.keys.sorted() {
            var units = unitsByGen[gen]!

            // Sort this row by parent's x-center so children cluster under parents
            units.sort { a, b in
                parentXCenter(unit: a, centerMap: centerMap) <
                parentXCenter(unit: b, centerMap: centerMap)
            }

            // Space evenly, centered on 0
            let totalW = units.reduce(0) { $0 + $1.width }
                       + CGFloat(max(units.count - 1, 0)) * Self.unitGap
            var cursor = -totalW / 2

            for i in 0..<units.count {
                units[i].xCenter = cursor + units[i].width / 2
                centerMap[units[i].primary.id] = units[i].xCenter
                if let sp = units[i].spouse { centerMap[sp.id] = units[i].xCenter }
                cursor += units[i].width + Self.unitGap
            }
            result[gen] = units
        }
        return result
    }

    /// Returns the sorting x-center for a unit based on the x-positions of its parents.
    /// If the primary person has two parents in different units, returns the midpoint.
    private func parentXCenter(unit: FamilyUnit, centerMap: [UUID: CGFloat]) -> CGFloat {
        var centers: [CGFloat] = []
        if let p = unit.primary.parent1ID.flatMap({ centerMap[$0] }) { centers.append(p) }
        if let p = unit.primary.parent2ID.flatMap({ centerMap[$0] }) { centers.append(p) }
        // Fall back to spouse's parents if primary has none in map yet
        if centers.isEmpty {
            if let p = unit.spouse?.parent1ID.flatMap({ centerMap[$0] }) { centers.append(p) }
            if let p = unit.spouse?.parent2ID.flatMap({ centerMap[$0] }) { centers.append(p) }
        }
        guard !centers.isEmpty else { return 0 }
        return centers.reduce(0, +) / CGFloat(centers.count)
    }

    /// The x coordinate from which to draw the edge from a single parent node.
    /// If the parent is in a couple *and the child shares only this parent* (split family),
    /// draw from the parent's own node rather than the couple midpoint.
    private func edgeSourceX(from parent: Person, posMap: [UUID: CGPoint]) -> CGFloat {
        guard let pos = posMap[parent.id] else { return 0 }
        return pos.x
    }
}
