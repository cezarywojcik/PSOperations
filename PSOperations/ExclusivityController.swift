/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
The file contains the code to automatically set up dependencies between mutually exclusive operations.
*/

import Foundation

/**
    `ExclusivityController` is a singleton to keep track of all the in-flight
    `Operation` instances that have declared themselves as requiring mutual exclusivity. 
    We use a singleton because mutual exclusivity must be enforced across the entire
    app, regardless of the `OperationQueue` on which an `Operation` was executed.
*/
public class ExclusivityController {
    static let sharedExclusivityController = ExclusivityController()
    
    private let serialQueue = dispatch_queue_create("Operations.ExclusivityController", DISPATCH_QUEUE_SERIAL)
    private var operations: [String: [AdvancedOperation]] = [:]
    
    private init() {
        /*
            A private initializer effectively prevents any other part of the app
            from accidentally creating an instance.
        */
    }
    
    /// Registers an operation as being mutually exclusive
    func addOperation(operation: AdvancedOperation, categories: [String]) {
        /*
            This needs to be a synchronous operation.
            If this were async, then we might not get around to adding dependencies 
            until after the operation had already begun, which would be incorrect.
        */
        dispatch_sync(serialQueue) {
            for category in categories {
                self.noqueue_addOperation(operation, category: category)
            }
        }
    }
    
    /// Unregisters an operation from being mutually exclusive.
    func removeOperation(operation: AdvancedOperation, categories: [String]) {
        dispatch_async(serialQueue) {
            for category in categories {
                self.noqueue_removeOperation(operation, category: category)
            }
        }
    }
    
    
    // MARK: AdvancedOperationManagement
    
    private func noqueue_addOperation(operation: AdvancedOperation, category: String) {
        var operationsWithThisCategory = operations[category] ?? []
        
        if let last = operationsWithThisCategory.last {
            operation.addDependency(last)
        }
        
        operationsWithThisCategory.append(operation)

        operations[category] = operationsWithThisCategory
    }
    
    private func noqueue_removeOperation(operation: AdvancedOperation, category: String) {
        let matchingOperations = operations[category]

        if var operationsWithThisCategory = matchingOperations,
           let index = operationsWithThisCategory.indexOf(operation) {

            operationsWithThisCategory.removeAtIndex(index)
            operations[category] = operationsWithThisCategory
        }
    }

    static public func debugData() -> OperationDebugData {
        let allCategoriesDebugData: [OperationDebugData] = sharedExclusivityController.operations.flatMap { (category, operationsArray) in
            guard !operationsArray.isEmpty else {
                return nil
            }
            let categoryDebugData = operationsArray.map { $0.debugData() }
            return OperationDebugData(description: category, subOperations: categoryDebugData)
        }
        return OperationDebugData(description: "\(self)", subOperations: allCategoriesDebugData)
    }

}
