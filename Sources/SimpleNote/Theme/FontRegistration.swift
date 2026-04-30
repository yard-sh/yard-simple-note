import Foundation
import CoreText

enum FontRegistration {
    static func registerBundledFonts() {
        let bundle = Bundle.module
        let extensions = ["ttf", "otf"]
        var urls: [URL] = []
        for ext in extensions {
            if let found = bundle.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") {
                urls.append(contentsOf: found)
            }
            if let found = bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                urls.append(contentsOf: found)
            }
        }

        for url in urls {
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !ok {
                if let cfError = error?.takeRetainedValue() {
                    let nsErr = cfError as Error as NSError
                    // Ignore "already registered" errors (code 105 / kCTFontManagerErrorAlreadyRegistered).
                    if nsErr.code != 105 {
                        FileHandle.standardError.write(Data("[SimpleNote] font registration failed for \(url.lastPathComponent): \(nsErr.localizedDescription)\n".utf8))
                    }
                }
            }
        }
    }
}
