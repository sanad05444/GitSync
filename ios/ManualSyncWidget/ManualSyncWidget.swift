import WidgetKit
import SwiftUI

struct ManualSyncWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ManualSyncWidgetEntry {
        ManualSyncWidgetEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ManualSyncWidgetEntry) -> Void) {
        let entry = ManualSyncWidgetEntry(date: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ManualSyncWidgetEntry>) -> Void) {
        let entries = [ManualSyncWidgetEntry(date: Date())]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct ManualSyncWidgetEntry: TimelineEntry {
    let date: Date
}

struct ManualSyncWidgetEntryView: View {
    var entry: ManualSyncWidgetProvider.Entry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        GeometryReader { geometry in 
            Button(
                action: { }
            ) {
                HStack(spacing: 16) {
                    Image("manual_sync_small")
                        .resizable()  
                        .scaledToFit() 
                        .foregroundColor(.white)
                        .frame(maxWidth: 48, maxHeight: 48)
                    
                    if geometry.size.width >= 140 {
                        Text("MANUAL SYNC")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }    
            .widgetURL(URL(string: "manualsyncwidget://click?homeWidget"))
            .buttonStyle(PlainButtonStyle())
            .widgetBackground(Color(red: 20/255, green: 20/255, blue: 20/255))
        }
    }
}

struct ManualSyncWidget: Widget {
    let kind: String = "ManualSyncWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ManualSyncWidgetProvider()) { entry in
            ManualSyncWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Manual Sync")
        .description("Widget to manual sync changes")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension View {
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
}
