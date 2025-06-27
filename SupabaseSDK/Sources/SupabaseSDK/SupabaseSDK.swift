
public class SupabaseSDK {
    private let config: SupabaseConfig
    
    public var auth: SupabaseAuth
    public var database: SupabaseDatabase
    
    public init(config: SupabaseConfig) {
        self.config = config
        auth = SupabaseAuth(config: config)
        database = SupabaseDatabase(config: config)
    }
}
