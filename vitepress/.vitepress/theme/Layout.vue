<script setup lang="ts">
import DefaultTheme from 'vitepress/theme'
import { useData } from 'vitepress'
import { computed } from 'vue'

const { Layout } = DefaultTheme
const { lang } = useData()

/** 中文站使用中文官方徽章（明/暗两套），英文站使用英文官方徽章。 */
const isZh = computed(() => lang.value.startsWith('zh'))
</script>

<template>
  <Layout>
    <template #home-hero-after>
      <div class="appgallery-entry">
        <a href="https://url.cloud.huawei.com/D0D1qLBUbK" target="_blank" rel="noreferrer">
          <template v-if="isZh">
            <img
              class="badge-light"
              src="/badges/appgallery-badge-light.png"
              alt="在华为应用市场下载源时"
            />
            <img
              class="badge-dark"
              src="/badges/appgallery-badge-dark.png"
              alt="在华为应用市场下载源时"
            />
          </template>
          <img
            v-else
            src="/badges/appgallery-badge-en.png"
            alt="Get SourceTime on AppGallery"
          />
        </a>
      </div>
    </template>
  </Layout>
</template>