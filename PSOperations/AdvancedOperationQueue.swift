/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
This file contains an NSOperationQueue subclass.
*/

import Foundation

/**
    The delegate of an `OperationQueue` can respond to `Operation` lifecycle
    events by implementing these methods.

    In general, implementing `OperationQueueDelegate` is not necessary; you would
    want to use an `OperationObserver` instead. However, there are a couple of
    situations where using `OperationQueueDelegate` can lead to simpler code.
    For example, `GroupOperation` is the delegate of its own internal
    `OperationQueue` and uses it to manage dependencies.
*/
@objc public protocol OperationQueueDelegate: NSObjectProtocol {
    optional func operationQueue(operationQueue: AdvancedOperationQueue, willAddOperation operation: NSOperation)
    optional func operationQueue(operationQueue: AdvancedOperationQueue, operationDidFinish operation: NSOperation, withErrors errors: [NSError])
}

/**
    `AdvancedOperationQueue` is an `NSOperationQueue` subclass that implements a large
    number of "extra features" related to the `AdvancedOperation` class:
    
    - Notifying a delegate of all operation completion
    - Extracting generated dependencies from operation conditions
    - Setting up dependencies to enforce mutual exclusivity
*/
public class AdvancedOperationQueue: NSOperationQueue, OperationDebuggable {
    private let opsQueue = dispatch_queue_create("com.psoperations", DISPATCH_QUEUE_SERIAL)
    private var ops: Set<NSOperation> = Set()
    
    public weak var delegate: OperationQueueDelegate?
    
    override public  func addOperation(operation: NSOperation) {
        if let op = operation as? AdvancedOperation {
            
            // Set up a `BlockObserver` to invoke the `OperationQueueDelegate` method.
            let delegate = BlockObserver(
                startHandler: nil,
                produceHandler: { [weak self] in
                    self?.addOperation($1)
                },
                finishHandler: { [weak self] finishedOperation, errors in
                    if let q = self {
                        
                        q.delegate?.operationQueue?(q, operationDidFinish: finishedOperation, withErrors: errors)
                        //Remove deps to avoid cascading deallocation error
                        //http://stackoverflow.com/questions/19693079/nsoperationqueue-bug-with-dependencies
                        finishedOperation.dependencies.forEach { finishedOperation.removeDependency($0) }
                    }
                }
            )
            op.addObserver(delegate)
            
            // Extract any dependencies needed by this operation.
            let dependencies = op.conditions.flatMap {
                $0.dependencyForOperation(op)
            }
                
            for dependency in dependencies {
                op.addDependency(dependency)

                self.addOperation(dependency)
            }
            
            /*
                With condition dependencies added, we can now see if this needs
                dependencies to enforce mutual exclusivity.
            */
            let concurrencyCategories: [String] = op.conditions.flatMap { condition in
                if !condition.dynamicType.isMutuallyExclusive { return nil }
                
                return "\(condition.dynamicType)"
            }

            if !concurrencyCategories.isEmpty {
                // Set up the mutual exclusivity dependencies.
                let exclusivityController = ExclusivityController.sharedExclusivityController

                exclusivityController.addOperation(op, categories: concurrencyCategories)
                
                op.addObserver(BlockObserver { operation, _ in
                    exclusivityController.removeOperation(operation, categories: concurrencyCategories)
                })
            }
        }
        else {
            /*
                For regular `NSOperation`s, we'll manually call out to the queue's 
                delegate we don't want to just capture "operation" because that     
                would lead to the operation strongly referencing itself and that's
                the pure definition of a memory leak.
            */
            operation.addCompletionBlock { [weak self, weak operation] in
                guard let queue = self, let operation = operation else { return }
                queue.delegate?.operationQueue?(queue, operationDidFinish: operation, withErrors: [])
                //Remove deps to avoid cascading deallocation error
                //http://stackoverflow.com/questions/19693079/nsoperationqueue-bug-with-dependencies
                operation.dependencies.forEach { operation.removeDependency($0) }
            }
        }
        
        delegate?.operationQueue?(self, willAddOperation: operation)
        super.addOperation(operation)
        
        /*
            Indicate to the operation that we've finished our extra work on it
            and it's now it a state where it can proceed with evaluating conditions,
            if appropriate.
        */
        if let op = operation as? AdvancedOperation {
            op.didEnqueue()
        }
    }
    
    override public func addOperations(ops: [NSOperation], waitUntilFinished wait: Bool) {
        /*
            The base implementation of this method does not call `addOperation()`,
            so we'll call it ourselves.
        */
        for operation in ops {
            addOperation(operation)
        }
        
        if wait {
            for operation in ops {
              operation.waitUntilFinished()
            }
        }
    }
    
    func addOpToSet(op: NSOperation) {
        dispatch_async(opsQueue) {
            self.ops.insert(op)
        }
    }
    
    func removeOpFromSet(op: NSOperation) {
        dispatch_async(opsQueue) {
            self.ops.remove(op)
        }
    }

    /**
     This method is used for debugging the current state of an `OperationQueue`.

     - returns: An `OperationDebugData` object containing debug data for the current `OperationQueue`.
     */
    public func debugData() -> OperationDebugData {
        let queueDebugData = operations.map { ($0 as? OperationDebuggable)?.debugData() ?? $0.debugDataNSOperation() }
        return OperationDebugData(
            description: "Queue",
            properties: [
                "numOperations": String(operations.count)
            ],
            subOperations: queueDebugData)
    }

}