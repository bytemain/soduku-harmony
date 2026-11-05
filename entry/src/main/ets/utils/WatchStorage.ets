import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { WatchSaveData, isValidWatchSave } from './WatchGameSession'

// Separate preference file and key: watch play never replaces the phone session.
const STORE_NAME = 'sudoku_watch_game'
const SAVE_KEY = 'watch_session_v1'

function getStore(context: Context): preferences.Preferences {
  const options: preferences.Options = { name: STORE_NAME }
  return preferences.getPreferencesSync(context, options)
}

export function loadWatchGame(context: Context): WatchSaveData | null {
  try {
    const json = getStore(context).getSync(SAVE_KEY, '') as string
    if (!json) return null
    const data = JSON.parse(json) as WatchSaveData
    return isValidWatchSave(data) ? data : null
  } catch (_) {
    return null
  }
}

/** putSync updates the in-process value immediately; flush persists it to disk. */
export async function saveWatchGame(context: Context, data: WatchSaveData): Promise<boolean> {
  if (!isValidWatchSave(data)) return false
  try {
    const store = getStore(context)
    store.putSync(SAVE_KEY, JSON.stringify(data))
    await store.flush()
    return true
  } catch (_) {
    return false
  }
}
