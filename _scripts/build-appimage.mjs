import { Arch, build, Platform } from 'electron-builder'
import config from './ebuilder.config.mjs'

const targets = Platform.LINUX.createTarget(['AppImage'], Arch.x64)

const output = await build({ targets, config, publish: 'never' })
console.log(output)
