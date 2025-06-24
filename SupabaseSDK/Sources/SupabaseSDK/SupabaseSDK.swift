
public class SupabaseSDK {
    private let config: SupabaseConfig
    
    public var auth: SupabaseAuth
    
    public init(config: SupabaseConfig) {
        self.config = config
        auth = SupabaseAuth(config: config)
    }
}
