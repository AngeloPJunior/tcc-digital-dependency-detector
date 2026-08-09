import Foundation
import CoreData

/// Stack CoreData definido em código, sem arquivo `.xcdatamodeld`.
///
/// Por que programático: o editor visual de modelo do Xcode não é
/// copiável/colável e é uma fonte recorrente de erro de configuração.
/// Definir o `NSManagedObjectModel` em Swift é CoreData legítimo, funciona
/// igual, e torna o schema versionável em texto puro no Git.
final class PersistenceController {

    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        let model = PersistenceController.makeModel()
        container = NSPersistentContainer(name: "DigitalDependency", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                // Em produção, tratar sem interromper a execução.
                assertionFailure("Falha ao carregar store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Falha ao salvar contexto: \(error)")
        }
    }

    // MARK: - Schema

    /// Entidade `AssessmentEntity`: uma avaliação de risco persistida.
    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "AssessmentEntity"
        entity.managedObjectClassName = NSStringFromClass(AssessmentEntity.self)

        func attribute(_ name: String,
                       _ type: NSAttributeType,
                       optional: Bool = false) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            return attr
        }

        entity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("date", .dateAttributeType),
            attribute("riskLevel", .integer16AttributeType),
            attribute("confidence", .doubleAttributeType),
            attribute("provenance", .stringAttributeType),
            attribute("probLow", .doubleAttributeType),
            attribute("probMedium", .doubleAttributeType),
            attribute("probHigh", .doubleAttributeType),
            attribute("daysMonitored", .integer16AttributeType),
            // Vetor de features serializado — permite auditar qualquer
            // predição depois, requisito de rastreabilidade do TCC.
            attribute("featuresJSON", .stringAttributeType, optional: true)
        ]

        model.entities = [entity]
        return model
    }
}

/// Objeto gerenciado correspondente à entidade `AssessmentEntity`.
@objc(AssessmentEntity)
final class AssessmentEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var date: Date
    @NSManaged var riskLevel: Int16
    @NSManaged var confidence: Double
    @NSManaged var provenance: String
    @NSManaged var probLow: Double
    @NSManaged var probMedium: Double
    @NSManaged var probHigh: Double
    @NSManaged var daysMonitored: Int16
    @NSManaged var featuresJSON: String?
}
