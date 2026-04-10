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
        guard let me = people.first(where: { $0.isMe }) else {
            // No "Me" — put everyone in unlinked section
            return TreeLayout(
                people: [], edges: [],
                size: CGSize(width: 400, height: 200),
                unlinked: people
            )
        }

        // 1. BFS from Me — assign generation numbers to every reachable person
        let genMap = assignGenerations(from: me)
        let linkedIDs = Set(genMap.keys)
        let unlinked  = people.filter { !linkedIDs.contains($0.id) }

        guard !genMap.isEmpty else { return TreeLayout.empty }

        // 2. Group people into family units (person + optional spouse) per generation
        var unitsByGen = groupIntoUnits(genMap: genMap)

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

        // Spouse link edges (short dashed horizontal line between the pair)
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

        // Parent-child edges (bezier curves from midpoint of couple → child top)
        for person in people {
            guard let childPos = posMap[person.id],
                  let pid      = person.parentID,
                  let parentPos = posMap[pid] else { continue }

            // Draw from the midpoint between parent and spouse (if applicable)
            let parentPerson = byID[pid]!
            let fromX: CGFloat
            if let sid   = parentPerson.spouseID,
               let spPos = posMap[sid] {
                fromX = (parentPos.x + spPos.x) / 2
            } else {
                fromX = parentPos.x
            }
            edges.append(TreeEdge(
                from: CGPoint(x: fromX,       y: parentPos.y + Self.nodeH / 2 + 4),
                to:   CGPoint(x: childPos.x,  y: childPos.y  - Self.nodeH / 2 - 4),
                kind: .parentChild
            ))
        }

        return TreeLayout(
            people:   positioned,
            edges:    edges,
            size:     CGSize(width: canvasW, height: canvasH),
            unlinked: unlinked
        )
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
            // Parent → one generation above
            if let pid = person.parentID, let par = byID[pid] {
                queue.append((par, gen - 1))
            }
            // Children → one generation below
            for child in children(of: person) {
                queue.append((child, gen + 1))
            }
            // Siblings (share same parentID) → same generation
            if let pid = person.parentID {
                let siblings = people.filter { $0.parentID == pid && $0.id != person.id }
                for sib in siblings { queue.append((sib, gen)) }
            }
        }
        return map
    }

    /// All children whose parentID points to this person or their spouse
    private func children(of person: Person) -> [Person] {
        people.filter {
            $0.parentID == person.id ||
            (person.spouseID != nil && $0.parentID == person.spouseID)
        }
    }

    // MARK: - Family unit grouping

    private func groupIntoUnits(genMap: [UUID: Int]) -> [Int: [FamilyUnit]] {
        var result    = [Int: [FamilyUnit]]()
        var processed = Set<UUID>()

        // Sort alphabetically so grouping is deterministic
        let sorted = people.sorted { $0.name < $1.name }

        for person in sorted {
            guard let gen = genMap[person.id],
                  !processed.contains(person.id) else { continue }

            // Try to pair with spouse if they're in the same generation
            if let sid    = person.spouseID,
               let spouse = byID[sid],
               let spGen  = genMap[sid],
               spGen == gen,
               !processed.contains(sid) {
                // Decide which is primary (the one whose parentID is in the tree)
                let primaryFirst = person.parentID != nil || spouse.parentID == nil
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

    /// Returns the x-center of the parent unit, or 0 if unknown (sorted to middle)
    private func parentXCenter(unit: FamilyUnit, centerMap: [UUID: CGFloat]) -> CGFloat {
        if let pid = unit.primary.parentID, let cx = centerMap[pid] { return cx }
        if let pid = unit.spouse?.parentID, let cx = centerMap[pid] { return cx }
        return 0
    }
}
