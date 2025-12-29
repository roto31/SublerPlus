import Foundation
import SublerPlusCore

/// Integration point for MCP Server with SublerPlus application
public struct MCPIntegration {
    /// Initialize and start the MCP server with application dependencies
    public static func startMCPServer(
        pipeline: MetadataPipeline,
        registry: ProvidersRegistry,
        statusStream: StatusStream,
        jobQueue: JobQueue,
        port: UInt16 = 8081,
        authToken: String? = nil
    ) throws -> MCPServer {
        let mcpServer = MCPServer(
            pipeline: pipeline,
            registry: registry,
            statusStream: statusStream,
            jobQueue: jobQueue,
            port: port,
            authToken: authToken
        )
        
        try mcpServer.start()
        return mcpServer
    }
}

